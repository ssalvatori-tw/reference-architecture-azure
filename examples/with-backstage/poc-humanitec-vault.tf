#
# Store credentials in Azure Vault insted of Humanitec Vault
# url: https://developer.humanitec.com/integration-and-extensions/humanitec-operator/how-tos/connect-to-azure-key-vault/
#

resource "azurerm_key_vault" "humanitec_poc" {
  name                = var.vault_name
  location            = module.base.az_resource_group_location
  resource_group_name = data.azurerm_resource_group.main.name

  tenant_id = data.azurerm_subscription.current.tenant_id

  sku_name                   = "premium"
  soft_delete_retention_days = 7
  enable_rbac_authorization  = true

}

# Create a role assignment for the current user
resource "azurerm_role_assignment" "self" {
  scope                = azurerm_key_vault.humanitec_poc.id
  principal_id         = data.azurerm_client_config.current.object_id
  role_definition_name = "Key Vault Administrator"
}

# Install Humanitec Operator
resource "helm_release" "humanitec_operator" {
  name       = "humanitec-operator"
  namespace  = var.humanitec_operator_namespace
  repository = "oci://registry.humanitec.io/charts"
  chart      = "humanitec-operator"
  version    = "0.1.8"

  force_update = true

  create_namespace = true

  set {
    name  = "controllerManager.serviceAccount.annotations.azure\\.workload\\.identity/client-id"
    value = azurerm_user_assigned_identity.operator.client_id
  }

  set {
    name  = "controllerManager.podLabels.azure\\.workload\\.identity/use"
    value = "true"
  }

  depends_on = [
    azurerm_user_assigned_identity.operator,
    azurerm_federated_identity_credential.vault
  ]
}


# Create managed identity
resource "azurerm_user_assigned_identity" "operator" {
  name                = var.operator_identity
  location            = module.base.az_resource_group_location
  resource_group_name = data.azurerm_resource_group.main.name
}

# createa federated identity credential
resource "azurerm_federated_identity_credential" "vault" {
  name                = var.operator_identity
  resource_group_name = module.base.az_resource_group_name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = module.base.aks_oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.operator.id
  subject             = format("system:serviceaccount:%s:%s", var.humanitec_operator_namespace, var.operator_service_account_name)
}

# Configure Key Vault access (Azure RBAC) 

# Cluster should have only read only access to tht secrets
data "azurerm_role_definition" "kv-secret-ro" {
  name = "Key Vault Secrets User"
}

data "azurerm_role_definition" "kv-secret-officer" {
  name = "Key Vault Secrets Officer"
}

# Asign a role (RO roles) to the managed identity
resource "azurerm_role_assignment" "vault-rw" {
  scope                = azurerm_key_vault.humanitec_poc.id
  role_definition_name = data.azurerm_role_definition.kv-secret-officer.name
  principal_id         = azurerm_user_assigned_identity.operator.principal_id
}

# Register the secret store with the Operator 
resource "kubernetes_manifest" "register_operator" {
  manifest = {
    apiVersion = "humanitec.io/v1alpha1"
    kind       = "SecretStore"
    metadata = {
      name      = var.secret_store_id
      namespace = var.humanitec_operator_namespace
      labels = {
        "app.humanitec.io/default-store" = "true"
      }
    }
    spec = {
      azurekv = {
        url      = azurerm_key_vault.humanitec_poc.vault_uri
        tenantID = data.azurerm_client_config.current.tenant_id
        auth : {}
      }
    }
  }
  depends_on = [helm_release.humanitec_operator]
}


# Create service principal for the Operator to access the vault
# Prepare service principal credentials for the Humanitec Operator 


resource "azuread_application" "humanitec_orchestrator_key_vault" {
  display_name = "humanitec_orchestrator_key_vault"
  description  = "Service Principal used by Humanitec Orchestrator to access Key Vault"
  owners       = [data.azuread_client_config.current.object_id]
}

resource "azuread_service_principal" "humanitec_orchestrator_vault" {
  client_id = azuread_application.humanitec_orchestrator_key_vault.client_id

  alternative_names = [var.orchestrator_sp_name]

  description = "Service Principal used by Humanitec Orchestrator to access Vault"

  owners = [data.azuread_client_config.current.object_id]
}

resource "azuread_service_principal_password" "humanitec_orchestrator_vault" {
  service_principal_id = azuread_service_principal.humanitec_orchestrator_vault.object_id
}

resource "azurerm_role_assignment" "humanitec_orchestrator_vault" {
  scope                = azurerm_key_vault.humanitec_poc.id
  role_definition_name = data.azurerm_role_definition.kv-secret-officer.name
  principal_id         = azuread_service_principal.humanitec_orchestrator_vault.id


  depends_on = [azurerm_key_vault.humanitec_poc]
}

# Register the secret store with the Platform Orchestrator

resource "humanitec_secretstore" "humanitec_orchestrator_officer" {
  id      = "azurepoc"
  primary = true
  azurekv = {
    url       = azurerm_key_vault.humanitec_poc.vault_uri
    tenant_id = data.azurerm_client_config.current.tenant_id
    auth = {
      client_id     = azuread_service_principal.humanitec_orchestrator_vault.client_id
      client_secret = azuread_service_principal_password.humanitec_orchestrator_vault.value
    }
  }

  depends_on = [azurerm_key_vault.humanitec_poc]
}


# This doesn't work  (terraform complains about a provider error but the creation works from the GUI)
#
# # Create reference to the secret stored in kv
# resource "humanitec_value" "poc_shared_secret" {
#   app_id      = humanitec_application.demo_app.id
#   key         = "shared_secret_001"
#   description = "Shared secret created in Terraform"
#   is_secret   = true
# }

# create secret in the vault
resource "azurerm_key_vault_secret" "master_secret" {
  name         = "master-secret"
  value        = "secret-password-001"
  key_vault_id = azurerm_key_vault.humanitec_poc.id
}


resource "azurerm_key_vault_secret" "mysql_username" {
  name         = "central-mysql-username"
  value        = "username-central-azure"
  key_vault_id = azurerm_key_vault.humanitec_poc.id
}

resource "azurerm_key_vault_secret" "mysql_password" {
  name         = "central-mysql-password"
  value        = "password-central-azure"
  key_vault_id = azurerm_key_vault.humanitec_poc.id
}

# Create a resource in humanitec
resource "humanitec_resource_definition" "mysql" {
  id          = "echo-mysql"
  name        = "central"
  type        = "mysql"
  driver_type = "humanitec/echo"

  driver_inputs = {
    values_string = jsonencode({
      name = "central-db1"
      host = "central.mysql.database.myapp.thoughtworks.com"
      user = azurerm_key_vault_secret.mysql_username.name
      port = 3306
    })
    secret_refs = jsonencode({
      username = {
        store = humanitec_secretstore.humanitec_orchestrator_officer.id
        ref   = azurerm_key_vault_secret.mysql_username.name
      }
      password = {
        store = humanitec_secretstore.humanitec_orchestrator_officer.id
        ref   = azurerm_key_vault_secret.mysql_password.name
      }
    })
  }

}

resource "humanitec_resource_definition" "cookie-config" {
  id          = "cookie-config"
  name        = "Cookie Config"
  type        = "config"
  driver_type = "humanitec/template"

  driver_inputs = {
    values_string = jsonencode({
      templates = {
        cookie = "resource demo cookies"
      }
    })
  }
}

resource "humanitec_resource_definition_criteria" "cookie-config" {
  resource_definition_id = humanitec_resource_definition.cookie-config.id
  env_type               = "development"
  env_id                 = "development"
}

#
# Create shared secret in the vault
#

resource "humanitec_application" "demo_app" {
  id   = "demo-app-terraform"
  name = "Demo App created via Terraform"
}


resource "azurerm_key_vault_secret" "client_api_token" {
  name         = "client-api-token"
  value        = uuid()
  key_vault_id = azurerm_key_vault.humanitec_poc.id
}


# Create reference to the secret stored in kv
resource "humanitec_value" "poc_shared_secret" {
  app_id      = humanitec_application.demo_app.id
  key         = "client-api-token"
  description = "client api token - shared secret created in Terraform "
  is_secret   = true
  secret_ref = {
    store = humanitec_secretstore.humanitec_orchestrator_officer.id
    ref   = azurerm_key_vault_secret.client_api_token.name
  }
}

