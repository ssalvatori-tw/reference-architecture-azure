variable "subscription_id" {
  description = "Azure Subscription (ID) to use"
  type        = string
}

variable "location" {
  description = "Azure region to deploy into"
  type        = string
}

variable "github_org_id" {
  description = "GitHub org id"
  type        = string
}

variable "humanitec_org_id" {
  description = "Humanitec Organization ID"
  type        = string
}

variable "humanitec_ci_service_user_token" {
  description = "Humanitec CI Service User Token"
  type        = string
  sensitive   = true
}

variable "vm_size" {
  description = "The Azure VM instances type to use as \"Agents\" (aka Kubernetes Nodes) in AKS"
  type        = string
  default     = "Standard_D2_v2"
}

variable "humanitec_envs" {
  type    = set(string)
  default = ["stagging", "production"]
}

variable "vault_name" {
  type    = string
  default = "humanitec-vault"
}

variable "vault_name_confidential" {
  type    = string
  default = "humanitec-vault-secret"
}


variable "orchestrator_sp_name" {
  type    = string
  default = "platform-orchestrator-sp-humanitec-vault"
}

variable "humanitec_operator_namespace" {
  type    = string
  default = "humanitec-operator-system"
}


variable "secret_store_id" {
  type    = string
  default = "azurepoc"
}

variable "secret_store_confidential_id" {
  type    = string
  default = "azurepoc-confidential"
}


variable "enable_orchestrator_access_confidential" {
  description = "Enable access to the confidential vault for the orchestrator"
  type        = bool
  default     = false
}

variable "operator_identity" {
  type    = string
  default = "humanitec-operator-identity"
}

variable "operator_service_account_name" {
  type    = string
  default = "humanitec-operator-controller-manager"
}

