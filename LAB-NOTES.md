# Lab Notes — Azure Landing-Zone Guardrails

> Running log, newest first.

## Known traps (pre-seeded)

### Policy evaluation is not instant

A newly assigned policy can take several minutes to enforce. If `test-deny`
unexpectedly *succeeds* right after `assign`, wait and retry before concluding the
policy is wrong — enforcement lag is real.

### Deny vs. the existing state

Deny policies block new/changed resources; they don't remove existing
non-compliant ones. If you already have a standing Owner assignment, the policy
won't retroactively kill it — it stops the next one. Note this distinction.

### AVM module versions move

`avm/res/key-vault/vault:0.9.0` is pinned. AVM modules version frequently; check
the registry for the current tag and record which you used.

### RBAC vs. access policies

The vault uses `enableRbacAuthorization: true`. If you're used to Key Vault access
policies, RBAC is a different model — worth a paragraph comparing the two from a
least-privilege standpoint.

## YYYY-MM-DD — <first real entry>

**Goal:** · **What happened:** · **Why:** · **Fix:** · **Time lost:**

## Open questions
- [ ] Does the Owner-deny policy also catch User Access Administrator (the other
      escalation route)?
- [ ] How long is enforcement lag in practice on a fresh assignment?
