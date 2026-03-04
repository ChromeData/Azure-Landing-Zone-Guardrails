.PHONY: help policy assign test-deny deploy-good report destroy scan
.DEFAULT_GOAL := help
SUB := $(shell az account show --query id -o tsv 2>/dev/null)

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

scan: ## Offline security scan of the Bicep (no Azure subscription needed)
	@# PSRule expands the template before evaluating, which is why it can read
	@# AVM modules. checkov cannot. See findings/bicep-scan-trap.txt.
	pwsh -c "Install-Module PSRule.Rules.Azure -Scope CurrentUser -Force -SkipPublisherCheck; 	  Invoke-PSRule -InputPath ./bicep/ -Module PSRule.Rules.Azure -Option ./ps-rule.yaml -Outcome Fail"

policy: ## Create the custom policy definitions
	az policy definition create --name lab10-deny-owner \
		--rules policy/deny-owner-assignment.json --mode All --subscription $(SUB)
	az policy definition create --name lab10-kv-protection \
		--rules policy/require-keyvault-protection.json --mode Indexed --subscription $(SUB)

assign: ## Assign the guardrails at subscription scope
	az policy assignment create --name lab10-guardrails \
		--scope "/subscriptions/$(SUB)" \
		--policy lab10-deny-owner
	az policy assignment create --name lab10-kv \
		--scope "/subscriptions/$(SUB)" \
		--policy lab10-kv-protection

test-deny: ## Attempt a direct Owner assignment, expect it to be DENIED
	@echo "This SHOULD fail with RequestDisallowedByPolicy, that is success."
	-az role assignment create --role Owner \
		--assignee "$$(az ad signed-in-user show --query id -o tsv)" \
		--scope "/subscriptions/$(SUB)"

deploy-good: ## Deploy a compliant hardened Key Vault via AVM (Bicep)
	az deployment group create -g lab10-rg -f bicep/keyvault.bicep

report: ## Pull compliance state
	az policy state summarize --subscription $(SUB)

destroy: ## Remove assignments + definitions
	-az policy assignment delete --name lab10-guardrails --scope "/subscriptions/$(SUB)"
	-az policy assignment delete --name lab10-kv --scope "/subscriptions/$(SUB)"
	-az policy definition delete --name lab10-deny-owner
	-az policy definition delete --name lab10-kv-protection
