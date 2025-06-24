locals {
  secrets = {
    AI-LANGUAGE-KEY = var.stage == "dev" ? azurerm_cognitive_account.ai_language[0].primary_access_key : data.azurerm_cognitive_account.test.primary_access_key

    FORM-RECOGNIZER-KEY = var.stage == "dev" ? azurerm_cognitive_account.ai_language[0].endpoint : data.azurerm_cognitive_account.test.primary_access_key
  }
}
