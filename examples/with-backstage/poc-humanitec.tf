# Create default maitenance configuration for azure
resource "azurerm_maintenance_configuration" "default" {
  name                = "default"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = module.base.az_resource_group_location
  scope               = "Host"
}

data "azurerm_resource_group" "main" {
  name = module.base.az_resource_group_name
}

resource "humanitec_environment_type" "poc-env" {
  for_each    = var.humanitec_envs
  id          = lower(each.key)
  description = format("Environment: %s", each.key)
}


data "azurerm_subscription" "current" {}
data "azuread_client_config" "current" {}
data "azurerm_client_config" "current" {}

# Application used by Humanitec to Access to Azure

resource "azuread_application" "humanitec_orchestrator" {
  display_name = "humanitec_orchestrator"
  owners = var.poc_users
  description  = "Humanitec Orcherstrator"
  # owners       = [data.azuread_client_config.current.object_id]
}

resource "azuread_service_principal" "humanitec_platform" {
  client_id = azuread_application.humanitec_orchestrator.client_id

  description                  = "Service Principal used by Humanitec Orchestrator"
  app_role_assignment_required = false
  owners = var.poc_users
  # owners = [data.azuread_client_config.current.object_id]
}

resource "time_rotating" "humanitec_platform" {
  rotation_days = 7
}

resource "azuread_service_principal_password" "humanitec_platform" {
  service_principal_id = azuread_service_principal.humanitec_platform.object_id
}

resource "azurerm_role_assignment" "humanitec_platform" {
  scope                = data.azurerm_resource_group.main.id
  role_definition_name = "Owner"
  principal_id         = azuread_service_principal.humanitec_platform.object_id
}

resource "humanitec_resource_account" "humanitec_azure" {
  type = "azure"
  id   = "azure-storage"
  name = "azure-storage"

  credentials = jsonencode({
    "appId" : azuread_service_principal.humanitec_platform.client_id,
    "displayName" : azuread_application.humanitec_orchestrator.display_name,
    "password" : azuread_service_principal_password.humanitec_platform.value,
    "tenant" : azuread_service_principal.humanitec_platform.application_tenant_id
  })

  depends_on = [azurerm_role_assignment.humanitec_platform]
}


