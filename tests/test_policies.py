"""Structural validation of the Azure Policy definitions.

These policies are the guardrails. A policy with a malformed rule, an invalid
effect, or the wrong role GUID doesn't fail loudly at deploy — it deploys and
quietly protects nothing. So each definition is checked here: shape, effect
parameter, and that the Owner-deny policy targets the real Owner role GUID.

Run:  python -m pytest tests/ -v
"""

import json
from pathlib import Path

import pytest

POLICY_DIR = Path(__file__).resolve().parent.parent / "policy"
POLICIES = sorted(POLICY_DIR.glob("*.json"))

# The well-known Azure built-in role definition ID for Owner. If the deny policy
# targets the wrong GUID, it blocks nothing and looks like it works.
OWNER_ROLE_ID = "8e3af657-a8ff-443c-a75c-2fe8c4bcb635"

VALID_EFFECTS = {"Deny", "Audit", "Disabled", "Append", "Modify", "DeployIfNotExists", "AuditIfNotExists"}


def load(path):
    return json.loads(path.read_text())


def test_there_are_policies():
    assert POLICIES, "no policy JSON found under policy/"


@pytest.mark.parametrize("path", POLICIES, ids=[p.name for p in POLICIES])
class TestPolicyShape:
    def test_is_valid_json(self, path):
        load(path)  # raises on malformed JSON

    def test_has_properties_and_rule(self, path):
        p = load(path)["properties"]
        assert "displayName" in p
        assert "policyRule" in p
        assert "if" in p["policyRule"] and "then" in p["policyRule"]

    def test_effect_is_parameterised_and_valid(self, path):
        p = load(path)["properties"]
        # Effect should be a parameter (so it can be dialed to Audit in prod first).
        assert "effect" in p.get("parameters", {}), "effect should be a parameter"
        allowed = set(p["parameters"]["effect"]["allowedValues"])
        assert allowed <= VALID_EFFECTS, f"invalid effect values: {allowed - VALID_EFFECTS}"

    def test_default_effect_is_deny(self, path):
        # These are guardrails, not suggestions. Default must block.
        p = load(path)["properties"]
        assert p["parameters"]["effect"]["defaultValue"] == "Deny"

    def test_then_references_effect_parameter(self, path):
        p = load(path)["properties"]
        assert p["policyRule"]["then"]["effect"] == "[parameters('effect')]"


class TestOwnerDenyPolicy:
    path = POLICY_DIR / "deny-owner-assignment.json"

    def test_targets_the_real_owner_role_guid(self):
        text = self.path.read_text()
        assert OWNER_ROLE_ID in text, (
            "Owner-deny policy does not reference the real Owner role GUID — "
            "it would deploy and block nothing."
        )

    def test_matches_role_assignments(self):
        p = load(self.path)["properties"]
        conditions = json.dumps(p["policyRule"]["if"])
        assert "Microsoft.Authorization/roleAssignments" in conditions


class TestKeyVaultPolicy:
    path = POLICY_DIR / "require-keyvault-protection.json"

    def test_checks_both_soft_delete_and_purge_protection(self):
        text = self.path.read_text()
        assert "enableSoftDelete" in text
        assert "enablePurgeProtection" in text

    def test_uses_anyof_so_either_missing_control_triggers(self):
        # A vault missing EITHER control must be denied, not only one missing both.
        p = load(self.path)["properties"]
        assert "anyOf" in json.dumps(p["policyRule"]["if"])
