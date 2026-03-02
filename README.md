# Lab 10 — Azure Landing-Zone Privileged-Access Guardrails

[![tests](https://github.com/ChromeData/Azure-Landing-Zone-Guardrails/actions/workflows/tests.yml/badge.svg)](https://github.com/ChromeData/Azure-Landing-Zone-Guardrails/actions/workflows/tests.yml)

**Rules that physically block the two most common Azure privilege mistakes:
standing Owner assignments, and Key Vaults that can be purged. Prevention at
subscription scope, not a report after the fact.**

| | |
|---|---|
| **Domains** | Azure · CyberArk/Idira (identity governance) |
| **Built on** | [Azure/azure-policy](https://github.com/Azure/azure-policy) + [Community-Policy](https://github.com/Azure/Community-Policy) (MIT) · [Azure Verified Modules](https://github.com/Azure/Azure-Verified-Modules) (MIT) |
| **Cost** | ~$1 · **Runtime** ~4 hours |
| **Status** | 🟡 Built, policies tested, not yet assigned |

---

## The point

PAM in Azure is mostly policy: the difference between a governed subscription and
an open one is whether standing privileged assignments are *prevented*, not just
detected. These guardrails deny the bad thing at deploy time, so it never exists
to be found.

## The two guardrails

**Deny direct Owner assignments.** Standing Owner is the single most common Azure
privileged-access finding. The policy blocks direct Owner role assignments so
elevation has to go through PIM (time-boxed, approved, audited) instead. This is
the Azure expression of "no standing privilege."

**Require Key Vault soft-delete + purge protection.** A vault that can be purged
is a vault whose secrets can be destroyed to cover tracks — directly a PAM
concern. The policy denies any vault missing *either* control.

Both ship with the effect as a **parameter** defaulting to `Deny`, so you can roll
them out in `Audit` first and flip to `Deny` once you've seen what they'd catch —
the standard safe-rollout pattern for org-wide policy.

## The guardrails are tested

A policy with a malformed rule or the wrong role GUID deploys fine and protects
*nothing* — it fails silent, the worst kind. **15 offline tests**
([`tests/test_policies.py`](./tests/test_policies.py)) check every definition:

- valid JSON, well-formed `if`/`then` rule
- effect is parameterised, defaults to `Deny`, and only uses real Azure effects
- the Owner-deny policy references the **actual** Owner role GUID
  (`8e3af657-…`) — the check that catches the silent-failure bug
- the Key Vault policy uses `anyOf`, so a vault missing *either* control is denied

```bash
python -m pytest tests/ -v
```

CI runs the policy tests and compiles the Bicep on every push.

## The compliant example

[`bicep/keyvault.bicep`](./bicep/keyvault.bicep) deploys a correctly-hardened Key
Vault via the Azure Verified Module — soft-delete, purge protection, no public
access. It's the mirror image of the deny path: proof the guardrail *passes* a
resource that's actually compliant, not just that it blocks bad ones.

## What I didn't build

The policy schema and AVM modules are Microsoft's. The two guardrail definitions,
the compliant example, and the tests are mine.

---

## Running it

```bash
python -m pytest tests/ -v                        # validate the guardrails
az deployment sub create ...                      # assign policies at scope
az deployment group create -f bicep/keyvault.bicep # deploy the compliant vault
```

Needs Python 3, and the Azure CLI + a subscription for the deploy steps.

## Findings

`findings/` fills in once assigned. [LAB-NOTES.md](./LAB-NOTES.md) is the log.

## License

Lab code: MIT ([LICENSE](./LICENSE)). Azure policy samples and AVM stay MIT,
credited above.
