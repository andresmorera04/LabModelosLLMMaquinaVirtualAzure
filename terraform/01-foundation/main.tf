resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_resource_provider_registration" "compute" {
  name = "Microsoft.Compute"

  feature {
    name       = "UseStandardSecurityType"
    registered = true
  }

  lifecycle {
    prevent_destroy = true
  }
}
