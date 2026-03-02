# Lab Notes — 10 Azure Landing-Zone Guardrails

Running log. Errors, dead ends, fixes, surprises. Dated, newest at the bottom.

---

## Format

```
### YYYY-MM-DD — what I was trying to do

**Expected:**
**Got:**
**Cause:**
**Fix:**
```

---

## Design decisions

### Effect as a parameter, defaulting to Deny

Org-wide policy is dangerous to roll out at full Deny on day one — you find out
what it blocks by breaking people's deploys. The effect is a parameter so it can
go out as Audit, get reviewed, then flip to Deny. Default is Deny because the
committed intent is a guardrail, not a suggestion.

### The Owner GUID is the silent-failure risk

`8e3af657-a8ff-443c-a75c-2fe8c4bcb635` is the built-in Owner role. Get it wrong
and the policy deploys, shows as assigned, and blocks nothing. A test asserts the
real GUID is present — this is the single most important check in the repo.

### anyOf on the Key Vault policy

A vault missing EITHER soft-delete OR purge protection must be denied, not only
one missing both. Used `anyOf`. A test pins it, because `allOf` there would be a
subtle hole that only bites on a partially-configured vault.

---

## Known traps (confirm on assignment)

- **Deny policies don't retro-fix.** Assigning the Owner-deny policy does not
  remove existing Owner assignments — it only blocks new ones. Existing standing
  Owners need a separate cleanup. Note this or someone assumes the subscription
  is clean when it isn't.
- **roleAssignments policy scope.** Confirm the policy evaluates at the scope you
  assign it — a management-group assignment behaves differently from a
  subscription one.
- **AVM module version pin.** `avm/res/key-vault/vault:0.9.0` — confirm it still
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

_(first entry goes here on the first assignment)_
