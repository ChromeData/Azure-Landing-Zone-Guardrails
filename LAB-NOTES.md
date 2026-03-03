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
