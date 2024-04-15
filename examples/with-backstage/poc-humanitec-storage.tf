resource "azurerm_storage_account" "storage_account_humanitec" {
  name                     = "humanitecplatformprod"
  resource_group_name      = module.base.az_resource_group_name
  location                 = module.base.az_resource_group_location
  account_tier             = "Standard" # Adjust tier and replication type as needed
  account_replication_type = "LRS"
}

# Create Storage Container
resource "azurerm_storage_container" "shared_container" {
  name                 = "shared"
  storage_account_name = azurerm_storage_account.storage_account_humanitec.name
}


resource "humanitec_resource_definition" "shared-storage" {
  driver_type = "humanitec/echo"
  id          = "shared-storage"
  name        = "shared-storage"
  type        = "azure-blob"

  driver_inputs = {
    values_string = jsonencode({
      "account"   = azurerm_storage_account.storage_account_humanitec.name,
      "container" = azurerm_storage_container.shared_container.name,
      "location"  = module.base.az_resource_group_location
    })
  }

}


resource "humanitec_resource_definition_criteria" "shared-storage" {
  resource_definition_id = humanitec_resource_definition.shared-storage.id
}

