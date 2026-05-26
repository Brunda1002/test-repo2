#!/usr/bin/env bash
# =============================================================================
# Template 2 — setup.sh
#
# WHEN TO RUN:
#   After Stage 1 (azure_infra job) completes successfully.
#   Before triggering Stage 2 (app_deploy job).
#
# WHY THIS EXISTS:
#   The GitHub Actions SP has an ABAC condition blocking roleAssignments/write.
#   Only role assignments live here — everything else is done by Terraform.
#
# WHAT IT DOES:
#   1. Reader on ALB resource      → ALB controller can read ALB config
#   2. Network Contributor on RG   → ALB controller can manage networking
#   3. Waits 5 min for RBAC to propagate
#
# AFTER THIS:
#   Go to GitHub Actions → Run workflow (workflow_dispatch)
#   This triggers Stage 2 which installs ALB controller + deploys the app.
# =============================================================================

set -euo pipefail

SUBSCRIPTION_ID="91ea5a42-5e9b-4c0c-a766-ea2a2aaa3ace"
RESOURCE_GROUP="rg-grouper-poc"
ALB_NAME="alb-grouper-poc"
ALB_IDENTITY_NAME="mi-alb-grouper-poc"

ok()   { echo "[OK]    $*"; }
info() { echo "[INFO]  $*"; }

az account set --subscription "$SUBSCRIPTION_ID"
ok "Subscription set."

PRINCIPAL_ID=$(az identity show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$ALB_IDENTITY_NAME" \
  --query principalId --output tsv)
ok "ALB identity principal: $PRINCIPAL_ID"

RG_ID="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}"
ALB_RESOURCE_ID="${RG_ID}/providers/Microsoft.ServiceNetworking/trafficControllers/${ALB_NAME}"

assign_role() {
  local ROLE="$1" SCOPE="$2" LABEL="$3"
  EXISTING=$(az role assignment list \
    --assignee "$PRINCIPAL_ID" --role "$ROLE" \
    --scope "$SCOPE" --query "length(@)" --output tsv 2>/dev/null || echo "0")
  if [[ "$EXISTING" -gt 0 ]]; then
    ok "$ROLE on $LABEL — already assigned, skipping."
  else
    az role assignment create \
      --assignee-object-id "$PRINCIPAL_ID" \
      --assignee-principal-type ServicePrincipal \
      --role "$ROLE" --scope "$SCOPE"
    ok "$ROLE on $LABEL — assigned."
  fi
}

echo -e "\n── Assigning roles"
assign_role "Reader"              "$ALB_RESOURCE_ID" "ALB resource"
assign_role "Network Contributor" "$RG_ID"           "resource group"

echo -e "\n── Waiting 5 min for RBAC to propagate..."
for i in $(seq 1 10); do sleep 30; info "  $((i*30))s elapsed"; done

echo ""
ok "Done. Now trigger Stage 2:"
echo "   GitHub Actions → Run workflow (workflow_dispatch) → Run workflow"
