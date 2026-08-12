# Lab 10 — Azure Landing-Zone Privileged-Access Guardrails

**Enforce privileged-access guardrails at Azure subscription scope with Azure
Policy — deny standing Owner assignments, require PIM-eligible elevation, mandate
Key Vault soft-delete/purge protection — and deploy the supporting resources with
Azure Verified Modules.**

| | |
|---|---|
| **Domains** | Azure · CyberArk/Idira (identity governance) |
| **Built on** | [Azure/azure-policy](https://github.com/Azure/azure-policy) + [Azure/Community-Policy](https://github.com/Azure/Community-Policy) (MIT) · [Azure/Azure-Verified-Modules](https://github.com/Azure/Azure-Verified-Modules) (MIT) |
| **Runtime** | ~4 hours · ~$1 |
| **Status** | 🟡 In progress |

---

## Why this lab exists

PAM in Azure is mostly policy: the difference between a governed subscription and an
open one is whether standing privileged assignments are *prevented*, not just
detected. This lab writes the guardrails as Azure Policy, assigns them at
subscription scope, and proves they block the bad thing — then deploys the
legitimate resources through Azure Verified Modules, the Microsoft-sanctioned module
program that replaced the now-deprecated CAF Terraform modules.

It's the Azure-native counterpart to your CyberArk governance work, and AVM is a
repo where a senior contribution is genuinely visible (see the earlier research).

## What I built

- A set of **custom Azure Policy definitions** targeting privileged-access risk:
  deny direct `Owner` role assignments at subscription scope, require Key Vault
  purge protection + soft delete, deny public network access on Key Vault, audit
  service principals with high-privilege Graph permissions.
- A **policy initiative** bundling them, assigned at subscription scope.
- **AVM-based deployment** of a hardened Key Vault to prove the guardrails pass the
  compliant resource and block the non-compliant one.
- A **compliance report** showing the deny in action.

## What I did not build

Azure Policy, the Community-Policy samples, and the Verified Modules are Microsoft's.
My work is the guardrail definitions, the initiative, the AVM configuration, and the
proof-of-enforcement write-up.

---

## Running it

```bash
make policy         # deploy the custom definitions + initiative
make assign         # assign the initiative at subscription scope
make test-deny      # attempt a direct Owner assignment -> should be DENIED
make deploy-good    # AVM hardened Key Vault -> should be COMPLIANT
make report         # pull compliance state
make destroy
```

## The proof

The screenshot worth keeping: an `az role assignment create` for Owner returning a
policy `RequestDisallowedByPolicy` error, next to a compliant Key Vault deploying
clean. That's enforcement, not audit — the distinction a governance reviewer cares
about.

| Guardrail | Enforced? | Test result |
|-----------|-----------|-------------|
| Deny direct Owner assignment | | |
| Require Key Vault purge protection | | |
| Deny Key Vault public access | | |
| Audit high-privilege service principals | | |

## What broke

See [LAB-NOTES.md](./LAB-NOTES.md).
