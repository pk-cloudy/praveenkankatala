terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      # version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  subscription_id = var.subscription_id
  features {}
}

#######################
# Variable Definitions
#######################
variable "subscription_id" {
  type        = string
  description = "Azure subscription id"
  default     = ""
}

variable "resource_group_name" {
  type        = string
  description = "Name of the existing resource group"
  default     = "test"
}

variable "location" {
  type        = string
  description = "Azure location"
  default     = "East Us"
}

variable "form_recognizer_name" {
  type        = string
  description = "Name suffix for form recognizer"
  default     = "form-recognizer"
}

variable "cognitive_services_sku" {
  type        = string
  description = "SKU for Cognitive Services"
  default     = "S0"
}

variable "document_custom_subdomain_name" {
  type        = string
  description = "Custom subdomain for the form recognizer"
  default     = "customdomain"
}

variable "key_vault_sku_name" {
  type        = string
  description = "SKU name for the Key Vault"
  default     = "standard"
}
variable "stage" {
  type        = string
  description = "Deployment stage (dev, qa, prod)"
  default     = "dev"
}
##############################################
# Conditional Cognitive Account: ai_language
##############################################
resource "azurerm_cognitive_account" "ai_language" {
  count               = var.stage == "dev" ? 1 : 0
  name                = "ai-language-delete-check"
  location            = var.location
  resource_group_name = var.resource_group_name
  kind                = "TextAnalytics"
  sku_name            = "S"
}

##############################################
# Conditional Cognitive Account: form_recognizer
##############################################
resource "azurerm_cognitive_account" "form_recognizer" {
  count                 = var.resource_group_name == "test" ? 1 : 0
  name                  = "${var.form_recognizer_name}-instance"
  location              = var.location
  resource_group_name   = var.resource_group_name
  kind                  = "FormRecognizer"
  sku_name              = var.cognitive_services_sku
  # custom_subdomain_name = var.document_custom_subdomain_name
}

resource "azurerm_key_vault" "key_vault" {
  name                = "test-keyvault-cond-check"
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = var.key_vault_sku_name

  # Basic access policy for the current user
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Get",
      "List",
      "Set",
      "Delete"
    ]
    key_permissions = [
      "Get",
      "Create",
      "Delete",
      "List"
    ]
    certificate_permissions = [
      "Get",
      "Import"
    ]
  }
}

###############################################################################
# Key Vault Secret
###############################################################################
resource "azurerm_key_vault_secret" "secrets" {
  for_each     = local.secrets
  name         = each.key
  value        = each.value
  key_vault_id = azurerm_key_vault.key_vault.id
  depends_on = [
    azurerm_key_vault.key_vault,
    azurerm_cognitive_account.ai_language
  ]
}
data "azurerm_client_config" "current" {}

data "azurerm_cognitive_account" "test" {
  name                = "test"
  resource_group_name = ""
}

