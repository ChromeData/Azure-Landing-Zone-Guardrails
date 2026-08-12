# Lab Notes, 10 Azure Landing-Zone Guardrails

Running log. Errors, dead ends, fixes, surprises. Dated, newest at the bottom.

---

## Format

```
### YYYY-MM-DD, what I was trying to do

**Expected:**
**Got:**
**Cause:**
**Fix:**
```

---

## Design decisions

### Effect as a parameter, defaulting to Deny

Org-wide policy is dangerous to roll out at full Deny on day one, you find out
what it blocks by breaking people's deploys. The effect is a parameter so it can
go out as Audit, get reviewed, then flip to Deny. Default is Deny because the
committed intent is a guardrail, not a suggestion.

### The Owner GUID is the silent-failure risk

`8e3af657-a8ff-443c-a75c-2fe8c4bcb635` is the built-in Owner role. Get it wrong
and the policy deploys, shows as assigned, and blocks nothing. A test asserts the
real GUID is present, this is the single most important check in the repo.

### anyOf on the Key Vault policy

A vault missing EITHER soft-delete OR purge protection must be denied, not only
one missing both. Used `anyOf`. A test pins it, because `allOf` there would be a
subtle hole that only bites on a partially-configured vault.

---

## Known traps (confirm on assignment)

- **Deny policies don't retro-fix.** Assigning the Owner-deny policy does not
  remove existing Owner assignments, it only blocks new ones. Existing standing
  Owners need a separate cleanup. Note this or someone assumes the subscription
  is clean when it isn't.
- **roleAssignments policy scope.** Confirm the policy evaluates at the scope you
  assign it, a management-group assignment behaves differently from a
  subscription one.
- **AVM module version pin.** `avm/res/key-vault/vault:0.9.0`, confirm it still
  resolves; AVM versions move.

---

## Open questions

- [ ] In Audit mode, how many existing Owner assignments does the policy flag?
- [ ] Does the Key Vault deny correctly block a vault created without purge
      protection? (Deploy one and confirm the deny fires.)
- [ ] Does the compliant Bicep vault deploy cleanly under the deny policy?
- [ ] Capture the policy compliance state for findings/.

---

## Log

### 2026-08-12, writing the tests found the risk worth testing for

Wrote the policy validator expecting it to be a formality. Writing
`test_targets_the_real_owner_role_guid` is what made the actual failure mode obvious:

A policy with the wrong role GUID **deploys successfully**, shows as Assigned in the
portal, reports compliant, and blocks nothing. There is no error anywhere. You would
only discover it the day someone assigns themselves Owner and the guardrail you were
relying on says nothing.

So the single most valuable test in this repo is a string check that
`8e3af657-a8ff-443c-a75c-2fe8c4bcb635` appears in the deny policy. Trivial test,
silent-failure class of bug.

Same reasoning drove the `anyOf` test on the Key Vault policy: `allOf` there would
only deny a vault missing *both* soft-delete and purge protection, silently permitting
one missing just one. Another passes-review, protects-nothing bug.

Final run: **15 passed** (`findings/test-run.txt`).

---

### 2026-08-12, Bicep build failed in CI

**Expected:** the release binary to download and compile the template.

**Got:** `##[error]Process completed with exit code 23` on the install step.

**Cause:** exit 23 is a curl write error fetching the `latest` release URL.

**Fix:** Switched to `az bicep install` / `az bicep build`. The Azure CLI is
preinstalled on the runner and manages its own Bicep, so there's no download step to
fail, and it handles the remote AVM module restore.

### 2026-08-12, scanned the Bicep offline, and both answers were wrong

No Azure subscription, but the Bicep can still be checked properly. `bicep build`
resolved `br/public:avm/res/key-vault/vault:0.9.0` from Microsoft's registry and
inlined it into 156 KB of ARM, which on its own verifies the module version and
every parameter name.

Then I ran checkov against it and got **zero checks**. Not zero failures, zero
rules evaluated, clean exit.

A Bicep module compiles to one top-level `Microsoft.Resources/deployments`
resource with the real resources nested under `properties.template.resources`.
Checkov's ARM parser does not descend into nested deployments, so it walks a
template containing a single resource it has no rules for and calls it a pass.
A gate wired that way green-lights every Bicep module ever written, including
one with public network access wide open. Same false-negative shape as the
gitleaks version drift in lab 07.

So I flattened the nested resources and rescanned. **5 failures**, including
purge protection, soft delete and public network access, all of which this
template sets correctly. They fail because the compiled values are ARM
expressions:

```
enableSoftDelete      = "[parameters('enableSoftDelete')]"
enablePurgeProtection = "[if(parameters('enablePurgeProtection'), ...)]"
```

Checkov compares those strings against a literal `true` and fails. Both runs are
useless, in opposite directions.

**PSRule for Azure is the tool that actually works**, because it expands the
template first and evaluates afterwards. It resolved the vault name to
`lab10kv5f3e65afb63bb`, meaning it evaluated `uniqueString(resourceGroup().id)`
rather than choking on it. 34 pass, 2 fail.

One of those two mattered:

```
Azure.KeyVault.Logs
  Minimum one diagnostic setting should have (AuditEvent) configured
```

The vault was hardened against access and kept **no record of who accessed it**.
For a PAM lab that is the entire subject, and it is the same hole CloudTrail
data events cover in lab 05. Fixed by wiring `diagnosticSettings` to the `audit`
category group, with the workspace id as a required parameter, because making it
optional is how the gap appeared in the first place. Also tagged the resource.

Now 36 pass, 0 fail.

**The part worth remembering:** checkov's five failures were all about settings
that were already correct, and the one setting genuinely missing never appeared
in either run. A scanner that reports the wrong five and misses the real one is
worse than no scanner, because it produces a report someone will believe.

PSRule now runs in CI, and `make scan` runs it locally. Neither needs a
subscription. Full detail in `findings/bicep-scan-trap.txt`.

The deny path still needs real Azure. That part has not moved.

---
