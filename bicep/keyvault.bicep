// Compliant Key Vault deployed via the Azure Verified Module for Key Vault.
// Proves the guardrails PASS a correctly-hardened resource (soft delete + purge
// protection + no public access), the mirror image of the test-deny path.
//
// AVM module reference: Azure/bicep-registry-modules -> avm/res/key-vault/vault
// (Microsoft's sanctioned module program; see the earlier repo research).

param location string = resourceGroup().location
param keyVaultName string = 'lab10kv${uniqueString(resourceGroup().id)}'

module vault 'br/public:avm/res/key-vault/vault:0.9.0' = {
  name: 'lab10-keyvault'
  params: {
    name: keyVaultName
    location: location
    enableSoftDelete: true          // required by the guardrail
    enablePurgeProtection: true     // required by the guardrail
    publicNetworkAccess: 'Disabled' // required by the guardrail
    enableRbacAuthorization: true   // RBAC over access policies — the modern default
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
    }
  }
}

output vaultName string = vault.outputs.name
