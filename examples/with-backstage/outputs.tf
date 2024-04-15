# output "aks_cluster_issuer_url" {
#   description = "Issuer URL for the OpenID Connect discovery endpoint"
#   value       = module.base.aks_oidc_issuer_url
# }
#
# output "user_assigned_identity" {
#   value = azurerm_user_assigned_identity.operator
# }
# output "tenant_id" {
#   value = data.azurerm_subscription.current.tenant_id
# }
#
# output "client_id" {
#   value = azuread_service_principal.humanitec_orchestrator_vault.client_id
# }
# output "secret_value" {
#   value = nonsensitive(azuread_service_principal_password.humanitec_orchestrator_vault.value)
# }
#
# output "humanitec_orchestrator_application" {
#   value = azuread_application.humanitec_orchestrator
# }
#
