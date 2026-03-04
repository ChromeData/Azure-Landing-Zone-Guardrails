// Parameter file used for offline scanning with PSRule.
//
// PSRule expands the template using these values, so the workspace id has to be
// a syntactically valid resource id for expansion to succeed. It is a
// placeholder: it makes the SHAPE of the configuration checkable without an
// Azure subscription. A real deployment passes a real workspace id.
//
// What this proves: the diagnostic setting is wired correctly and the audit
// category group is right. What it does not prove: that logs actually arrive.
// That needs Azure.

using './keyvault.bicep'

param logAnalyticsWorkspaceId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab10-rg/providers/Microsoft.OperationalInsights/workspaces/lab10-logs'
