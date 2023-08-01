// Compliant Key Vault deployed via the Azure Verified Module for Key Vault.
// Proves the guardrails PASS a correctly-hardened resource (soft delete +
// purge protection + no public access), the mirror image of the test-deny path.
//
// AVM module reference: Azure/bicep-registry-modules -> avm/res/key-vault/vault
// (Microsoft's sanctioned module program; see the earlier repo research).
//
// Verified offline with PSRule for Azure, which expands the template before
// evaluating rules. See findings/bicep-scan-trap.txt for why checkov cannot
// read this file usefully and PSRule can.

param location string = resourceGroup().location
param keyVaultName string = 'lab10kv${uniqueString(resourceGroup().id)}'

@description('''
Log Analytics workspace that receives Key Vault AuditEvent logs.

Required, deliberately with no default. PSRule's Azure.KeyVault.Logs rule
failed the first version of this file: the vault was hardened against access
and kept no record of who accessed it. For a PAM lab that is the whole point,
so it is a required input rather than an optional extra.

Same gap CloudTrail data events cover in lab 05. A vault nobody can reach is
only half the control; the other half is knowing who reached it.
''')
param logAnalyticsWorkspaceId string

@description('Standard tags. PSRule Azure.Resource.UseTags requires these.')
param tags object = {
  Purpose: 'pam-cloud-lab'
  Lab: '10-azure-landing-zone-guardrails'
}

module vault 'br/public:avm/res/key-vault/vault:0.9.0' = {
  name: 'lab10-keyvault'
  params: {
    name: keyVaultName
    location: location
    tags: tags
    enableSoftDelete: true          // required by the guardrail
    enablePurgeProtection: true     // required by the guardrail
    publicNetworkAccess: 'Disabled' // required by the guardrail
    enableRbacAuthorization: true   // RBAC over access policies, the modern default
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
    }

    // The audit trail. 'audit' is the category group carrying AuditEvent,
    // which is the record of every secret read, write and delete.
    diagnosticSettings: [
      {
        name: 'lab10-audit'
        workspaceResourceId: logAnalyticsWorkspaceId
        logCategoriesAndGroups: [
          {
            categoryGroup: 'audit'
          }
        ]
      }
    ]
  }
}

output vaultName string = vault.outputs.name
