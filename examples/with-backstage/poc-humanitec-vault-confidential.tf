#
# Connect humanitec with condifdential secrets stored in Azure Key Vault
# Humanitec Orchestrator should not have access to the vault in any ways, just the kubernetes operator should but as RO
# 

resource "azurerm_key_vault" "humanitec_poc_confidential" {
  name                = var.vault_name_confidential
  location            = module.base.az_resource_group_location
  resource_group_name = data.azurerm_resource_group.main.name

  tenant_id = data.azurerm_subscription.current.tenant_id

  sku_name                   = "premium"
  soft_delete_retention_days = 7
  enable_rbac_authorization  = true

}

# Create a role assignment for the current user
resource "azurerm_role_assignment" "self-confidential" {
  scope                = azurerm_key_vault.humanitec_poc_confidential.id
  principal_id         = data.azurerm_client_config.current.object_id
  role_definition_name = "Key Vault Administrator"
}


#
# Humanitec Operator should have RO access to the confidential vault
#

# Asign a role to the managed identity used by Humanitec Operator
resource "azurerm_role_assignment" "vault-confidential-confidential-ro" {
  scope                = azurerm_key_vault.humanitec_poc_confidential.id
  role_definition_name = data.azurerm_role_definition.kv-secret-ro.name
  principal_id         = azurerm_user_assigned_identity.operator.principal_id
}


# Register the secret store confidential with the Operator 

resource "kubernetes_manifest" "register_operator_secret_store_confidential" {
  manifest = {
    apiVersion = "humanitec.io/v1alpha1"
    kind       = "SecretStore"
    metadata = {
      name      = var.secret_store_confidential_id
      namespace = var.humanitec_operator_namespace
      labels = {
        "app.humanitec.io/default-store" = "false"
      }
    }
    spec = {
      azurekv = {
        url      = azurerm_key_vault.humanitec_poc_confidential.vault_uri
        tenantID = data.azurerm_client_config.current.tenant_id
        auth : {}
      }
    }
  }
  depends_on = [helm_release.humanitec_operator]

}


#
# TODO: Ask Humanitec SME does the orchestrator need to have access to the vault even as RO?
# If we are just using references only the k8s should have access the Humanitec Orchestrator shouldn't 

resource "azurerm_role_assignment" "humanitec_orchestrator_vault_confidential" {
  count = var.enable_orchestrator_access_confidential ? 1 : 0

  scope                = azurerm_key_vault.humanitec_poc_confidential.id
  role_definition_name = data.azurerm_role_definition.kv-secret-ro.name
  principal_id         = azuread_service_principal.humanitec_orchestrator_vault.id

  depends_on = [azurerm_key_vault.humanitec_poc_confidential]
}

# Register the secret store with the Platform Orchestrator

resource "humanitec_secretstore" "humanitec_orchestrator_officer_confidential" {
  id = "azurepoc-confidential"
  # primary = true
  azurekv = {
    url       = azurerm_key_vault.humanitec_poc_confidential.vault_uri
    tenant_id = data.azurerm_client_config.current.tenant_id
    auth = {
      client_id     = azuread_service_principal.humanitec_orchestrator_vault.client_id
      client_secret = azuread_service_principal_password.humanitec_orchestrator_vault.value
    }
  }

  depends_on = [azurerm_key_vault.humanitec_poc_confidential]
}

# create secret in the vault
resource "azurerm_key_vault_secret" "master_secret_confidential" {
  name         = "master-secret"
  value        = "secret-password-confidential-001"
  key_vault_id = azurerm_key_vault.humanitec_poc_confidential.id
}


resource "azurerm_key_vault_secret" "mysql_username_confidential" {
  name         = "central-mysql-username"
  value        = "username-central-confidential-azure"
  key_vault_id = azurerm_key_vault.humanitec_poc_confidential.id
}

resource "azurerm_key_vault_secret" "mysql_password_confidential" {
  name         = "central-mysql-password"
  value        = "password-central-confidential-azure"
  key_vault_id = azurerm_key_vault.humanitec_poc_confidential.id
}

# Create a resource in humanitec this should be used only in production
resource "humanitec_resource_definition" "mysql-confidential" {
  id          = "mysql-confidential"
  name        = "central-confidential"
  type        = "mysql"
  driver_type = "humanitec/echo"

  driver_inputs = {
    values_string = jsonencode({
      name = "central-db1"
      host = "central.mysql.database.confidential.myapp.thoughtworks.com"
      user = azurerm_key_vault_secret.mysql_username_confidential.name
      port = 3306
    })
    secret_refs = jsonencode({
      username = {
        store = humanitec_secretstore.humanitec_orchestrator_officer_confidential.id
        ref   = azurerm_key_vault_secret.mysql_username_confidential.name
      }
      password = {
        store = humanitec_secretstore.humanitec_orchestrator_officer_confidential.id
        ref   = azurerm_key_vault_secret.mysql_password_confidential.name
      }
    })
  }

  depends_on = [humanitec_secretstore.humanitec_orchestrator_officer_confidential]

}

resource "humanitec_resource_definition_criteria" "mysql-confidential" {
  resource_definition_id = humanitec_resource_definition.mysql-confidential.id
  env_type               = "production"
  env_id                 = "production"
}

#
# Create shared secret in the vault
#
resource "azurerm_key_vault_secret" "client_api_token_confidential" {
  name         = "client-api-token"
  value        = uuid()
  key_vault_id = azurerm_key_vault.humanitec_poc_confidential.id
}


# Create reference to the secret stored in kv
# resource "humanitec_value" "poc_shared_secret_confidential" {
#   app_id      = humanitec_application.demo_app.id
#   key         = "client-api-token"
#   description = "client api token - shared secret created in Terraform "
#   is_secret   = true
#   secret_ref = {
#     store = humanitec_secretstore.humanitec_orchestration_officer_confidential.id
#     ref   = azurerm_key_vault_secret.client_api_token_confidential.name
#   }
# }


