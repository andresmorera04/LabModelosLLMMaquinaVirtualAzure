
# Resultado de Validación Manual — Spec `compute`

Corrida iniciada: 2026-07-07 18:04:02

### Paso 1a: Verificación de state previo a reaplicar — 2026-07-07 18:04:32
```
--- 01-foundation state ---
azurerm_resource_provider_registration.compute
--- 02-networking state ---
```

### Paso 1b: terraform plan en 01-foundation (recreación completa) — 2026-07-07 18:05:21
```
[0m[1mInitializing provider plugins found in the configuration...[0m
- Reusing previous version of hashicorp/azurerm from the dependency lock file
- Using previously-installed hashicorp/azurerm v4.80.0

[0m[1mInitializing the backend...[0m

[0m[1mInitializing provider plugins found in the state...[0m
- Reusing previous version of hashicorp/azurerm
- Using previously-installed hashicorp/azurerm v4.80.0


[0m[1m[32mTerraform has been successfully initialized![0m[32m[0m
[0m[32m
You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.[0m
azurerm_resource_provider_registration.compute: Refreshing state... [id=/subscriptions/3e9dda65-6318-441d-9cd1-323be07d7a58/providers/Microsoft.Compute]

Terraform used the selected providers to generate the following execution
plan. Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # azurerm_resource_group.main will be created
  + resource "azurerm_resource_group" "main" {
      + id       = (known after apply)
      + location = "eastus2"
      + name     = "rg-llm-lab-ejemplo1"
      + tags     = {
          + "environment" = "Laboratorio"
          + "owner"       = "Andres Morera"
          + "project"     = "ModeloLLMOpensource"
        }
    }

Plan: 1 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  ~ resource_group_id   = "/subscriptions/3e9dda65-6318-441d-9cd1-323be07d7a58/resourceGroups/rg-llm-lab-ejemplo1" -> (known after apply)

─────────────────────────────────────────────────────────────────────────────

Note: You didn't use the -out option to save this plan, so Terraform can't
guarantee to take exactly these actions if you run "terraform apply" now.
```

### Paso 1c: terraform apply en 01-foundation — 2026-07-07 18:06:08
```
azurerm_resource_provider_registration.compute: Refreshing state... [id=/subscriptions/3e9dda65-6318-441d-9cd1-323be07d7a58/providers/Microsoft.Compute]

Terraform used the selected providers to generate the following execution
plan. Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # azurerm_resource_group.main will be created
  + resource "azurerm_resource_group" "main" {
      + id       = (known after apply)
      + location = "eastus2"
      + name     = "rg-llm-lab-ejemplo1"
      + tags     = {
          + "environment" = "Laboratorio"
          + "owner"       = "Andres Morera"
          + "project"     = "ModeloLLMOpensource"
        }
    }

Plan: 1 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  ~ resource_group_id   = "/subscriptions/3e9dda65-6318-441d-9cd1-323be07d7a58/resourceGroups/rg-llm-lab-ejemplo1" -> (known after apply)
azurerm_resource_group.main: Creating...
azurerm_resource_group.main: Still creating... [00m10s elapsed]
azurerm_resource_group.main: Still creating... [00m20s elapsed]
azurerm_resource_group.main: Creation complete after 29s [id=/subscriptions/3e9dda65-6318-441d-9cd1-323be07d7a58/resourceGroups/rg-llm-lab-ejemplo1]

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.

Outputs:

location = "eastus2"
resource_group_id = "/subscriptions/3e9dda65-6318-441d-9cd1-323be07d7a58/resourceGroups/rg-llm-lab-ejemplo1"
resource_group_name = "rg-llm-lab-ejemplo1"
```
### Outputs resultantes de 01-foundation
```
location = "eastus2"
resource_group_id = "/subscriptions/3e9dda65-6318-441d-9cd1-323be07d7a58/resourceGroups/rg-llm-lab-ejemplo1"
resource_group_name = "rg-llm-lab-ejemplo1"
```

### Paso 1d: terraform plan en 02-networking (recreación completa) — 2026-07-07 18:36:04
```
[0m[1mInitializing provider plugins found in the configuration...[0m
- Reusing previous version of hashicorp/azurerm from the dependency lock file
- Using previously-installed hashicorp/azurerm v4.80.0

[0m[1mInitializing the backend...[0m

[0m[1mInitializing provider plugins found in the state...[0m


[0m[1m[32mTerraform has been successfully initialized![0m[32m[0m
[0m[32m
You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.[0m

Terraform used the selected providers to generate the following execution
plan. Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # azurerm_network_security_group.main will be created
  + resource "azurerm_network_security_group" "main" {
      + id                  = (known after apply)
      + location            = "eastus2"
      + name                = "vm-ollama-h100-nsg"
      + resource_group_name = "rg-llm-lab-ejemplo1"
      + security_rule       = [
          + {
              + access                                     = "Allow"
              + destination_address_prefix                 = "*"
              + destination_address_prefixes               = []
              + destination_application_security_group_ids = []
              + destination_port_range                     = "11434"
              + destination_port_ranges                    = []
              + direction                                  = "Inbound"
              + name                                       = "Allow-Ollama"
              + priority                                   = 1002
              + protocol                                   = "Tcp"
              + source_address_prefix                      = "201.191.218.251/32"
              + source_address_prefixes                    = []
              + source_application_security_group_ids      = []
              + source_port_range                          = "*"
              + source_port_ranges                         = []
                # (1 unchanged attribute hidden)
            },
          + {
              + access                                     = "Allow"
              + destination_address_prefix                 = "*"
              + destination_address_prefixes               = []
              + destination_application_security_group_ids = []
              + destination_port_range                     = "22"
              + destination_port_ranges                    = []
              + direction                                  = "Inbound"
              + name                                       = "Allow-SSH"
              + priority                                   = 1001
              + protocol                                   = "Tcp"
              + source_address_prefix                      = "201.191.218.251/32"
              + source_address_prefixes                    = []
              + source_application_security_group_ids      = []
              + source_port_range                          = "*"
              + source_port_ranges                         = []
                # (1 unchanged attribute hidden)
            },
        ]
    }

  # azurerm_public_ip.main will be created
  + resource "azurerm_public_ip" "main" {
      + allocation_method       = "Static"
      + ddos_protection_mode    = "VirtualNetworkInherited"
      + fqdn                    = (known after apply)
      + id                      = (known after apply)
      + idle_timeout_in_minutes = 4
      + ip_address              = (known after apply)
      + ip_version              = "IPv4"
      + location                = "eastus2"
      + name                    = "vm-ollama-h100-pip"
      + resource_group_name     = "rg-llm-lab-ejemplo1"
      + sku                     = "Standard"
      + sku_tier                = "Regional"
    }

  # azurerm_subnet.main will be created
  + resource "azurerm_subnet" "main" {
      + address_prefixes                              = [
          + "10.0.1.0/24",
        ]
      + default_outbound_access_enabled               = true
      + id                                            = (known after apply)
      + name                                          = "vm-ollama-h100-subnet"
      + private_endpoint_network_policies             = "Disabled"
      + private_link_service_network_policies_enabled = true
      + resource_group_name                           = "rg-llm-lab-ejemplo1"
      + virtual_network_name                          = "vm-ollama-h100-vnet"
    }

  # azurerm_subnet_network_security_group_association.main will be created
  + resource "azurerm_subnet_network_security_group_association" "main" {
      + id                        = (known after apply)
      + network_security_group_id = (known after apply)
      + subnet_id                 = (known after apply)
    }

  # azurerm_virtual_network.main will be created
  + resource "azurerm_virtual_network" "main" {
      + address_space                  = [
          + "10.0.0.0/16",
        ]
      + dns_servers                    = (known after apply)
      + guid                           = (known after apply)
      + id                             = (known after apply)
      + location                       = "eastus2"
      + name                           = "vm-ollama-h100-vnet"
      + private_endpoint_vnet_policies = "Disabled"
      + resource_group_name            = "rg-llm-lab-ejemplo1"
      + subnet                         = (known after apply)
    }

Plan: 5 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + nsg_id            = (known after apply)
  + public_ip_address = (known after apply)
  + public_ip_id      = (known after apply)
  + subnet_id         = (known after apply)

─────────────────────────────────────────────────────────────────────────────

Note: You didn't use the -out option to save this plan, so Terraform can't
guarantee to take exactly these actions if you run "terraform apply" now.
```

### Paso 1e: terraform apply en 02-networking — 2026-07-07 18:37:20
```

Terraform used the selected providers to generate the following execution
plan. Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # azurerm_network_security_group.main will be created
  + resource "azurerm_network_security_group" "main" {
      + id                  = (known after apply)
      + location            = "eastus2"
      + name                = "vm-ollama-h100-nsg"
      + resource_group_name = "rg-llm-lab-ejemplo1"
      + security_rule       = [
          + {
              + access                                     = "Allow"
              + destination_address_prefix                 = "*"
              + destination_address_prefixes               = []
              + destination_application_security_group_ids = []
              + destination_port_range                     = "11434"
              + destination_port_ranges                    = []
              + direction                                  = "Inbound"
              + name                                       = "Allow-Ollama"
              + priority                                   = 1002
              + protocol                                   = "Tcp"
              + source_address_prefix                      = "201.191.218.251/32"
              + source_address_prefixes                    = []
              + source_application_security_group_ids      = []
              + source_port_range                          = "*"
              + source_port_ranges                         = []
                # (1 unchanged attribute hidden)
            },
          + {
              + access                                     = "Allow"
              + destination_address_prefix                 = "*"
              + destination_address_prefixes               = []
              + destination_application_security_group_ids = []
              + destination_port_range                     = "22"
              + destination_port_ranges                    = []
              + direction                                  = "Inbound"
              + name                                       = "Allow-SSH"
              + priority                                   = 1001
              + protocol                                   = "Tcp"
              + source_address_prefix                      = "201.191.218.251/32"
              + source_address_prefixes                    = []
              + source_application_security_group_ids      = []
              + source_port_range                          = "*"
              + source_port_ranges                         = []
                # (1 unchanged attribute hidden)
            },
        ]
    }

  # azurerm_public_ip.main will be created
  + resource "azurerm_public_ip" "main" {
      + allocation_method       = "Static"
      + ddos_protection_mode    = "VirtualNetworkInherited"
      + fqdn                    = (known after apply)
      + id                      = (known after apply)
      + idle_timeout_in_minutes = 4
      + ip_address              = (known after apply)
      + ip_version              = "IPv4"
      + location                = "eastus2"
      + name                    = "vm-ollama-h100-pip"
      + resource_group_name     = "rg-llm-lab-ejemplo1"
      + sku                     = "Standard"
      + sku_tier                = "Regional"
    }

  # azurerm_subnet.main will be created
  + resource "azurerm_subnet" "main" {
      + address_prefixes                              = [
          + "10.0.1.0/24",
        ]
      + default_outbound_access_enabled               = true
      + id                                            = (known after apply)
      + name                                          = "vm-ollama-h100-subnet"
      + private_endpoint_network_policies             = "Disabled"
      + private_link_service_network_policies_enabled = true
      + resource_group_name                           = "rg-llm-lab-ejemplo1"
      + virtual_network_name                          = "vm-ollama-h100-vnet"
    }

  # azurerm_subnet_network_security_group_association.main will be created
  + resource "azurerm_subnet_network_security_group_association" "main" {
      + id                        = (known after apply)
      + network_security_group_id = (known after apply)
      + subnet_id                 = (known after apply)
    }

  # azurerm_virtual_network.main will be created
  + resource "azurerm_virtual_network" "main" {
      + address_space                  = [
          + "10.0.0.0/16",
        ]
      + dns_servers                    = (known after apply)
      + guid                           = (known after apply)
      + id                             = (known after apply)
      + location                       = "eastus2"
      + name                           = "vm-ollama-h100-vnet"
      + private_endpoint_vnet_policies = "Disabled"
      + resource_group_name            = "rg-llm-lab-ejemplo1"
      + subnet                         = (known after apply)
    }

Plan: 5 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + nsg_id            = (known after apply)
  + public_ip_address = (known after apply)
  + public_ip_id      = (known after apply)
  + subnet_id         = (known after apply)
azurerm_virtual_network.main: Creating...
azurerm_public_ip.main: Creating...
azurerm_network_security_group.main: Creating...
azurerm_network_security_group.main: Creation complete after 4s [id=/subscriptions/3e9dda65-6318-441d-9cd1-323be07d7a58/resourceGroups/rg-llm-lab-ejemplo1/providers/Microsoft.Network/networkSecurityGroups/vm-ollama-h100-nsg]
azurerm_public_ip.main: Creation complete after 5s [id=/subscriptions/3e9dda65-6318-441d-9cd1-323be07d7a58/resourceGroups/rg-llm-lab-ejemplo1/providers/Microsoft.Network/publicIPAddresses/vm-ollama-h100-pip]
azurerm_virtual_network.main: Creation complete after 6s [id=/subscriptions/3e9dda65-6318-441d-9cd1-323be07d7a58/resourceGroups/rg-llm-lab-ejemplo1/providers/Microsoft.Network/virtualNetworks/vm-ollama-h100-vnet]
azurerm_subnet.main: Creating...
azurerm_subnet.main: Creation complete after 6s [id=/subscriptions/3e9dda65-6318-441d-9cd1-323be07d7a58/resourceGroups/rg-llm-lab-ejemplo1/providers/Microsoft.Network/virtualNetworks/vm-ollama-h100-vnet/subnets/vm-ollama-h100-subnet]
azurerm_subnet_network_security_group_association.main: Creating...
azurerm_subnet_network_security_group_association.main: Creation complete after 7s [id=/subscriptions/3e9dda65-6318-441d-9cd1-323be07d7a58/resourceGroups/rg-llm-lab-ejemplo1/providers/Microsoft.Network/virtualNetworks/vm-ollama-h100-vnet/subnets/vm-ollama-h100-subnet]

Apply complete! Resources: 5 added, 0 changed, 0 destroyed.

Outputs:

nsg_id = "/subscriptions/3e9dda65-6318-441d-9cd1-323be07d7a58/resourceGroups/rg-llm-lab-ejemplo1/providers/Microsoft.Network/networkSecurityGroups/vm-ollama-h100-nsg"
public_ip_address = "137.116.36.202"
public_ip_id = "/subscriptions/3e9dda65-6318-441d-9cd1-323be07d7a58/resourceGroups/rg-llm-lab-ejemplo1/providers/Microsoft.Network/publicIPAddresses/vm-ollama-h100-pip"
subnet_id = "/subscriptions/3e9dda65-6318-441d-9cd1-323be07d7a58/resourceGroups/rg-llm-lab-ejemplo1/providers/Microsoft.Network/virtualNetworks/vm-ollama-h100-vnet/subnets/vm-ollama-h100-subnet"
```
### Outputs resultantes de 02-networking
```
nsg_id = "/subscriptions/3e9dda65-6318-441d-9cd1-323be07d7a58/resourceGroups/rg-llm-lab-ejemplo1/providers/Microsoft.Network/networkSecurityGroups/vm-ollama-h100-nsg"
public_ip_address = "137.116.36.202"
public_ip_id = "/subscriptions/3e9dda65-6318-441d-9cd1-323be07d7a58/resourceGroups/rg-llm-lab-ejemplo1/providers/Microsoft.Network/publicIPAddresses/vm-ollama-h100-pip"
subnet_id = "/subscriptions/3e9dda65-6318-441d-9cd1-323be07d7a58/resourceGroups/rg-llm-lab-ejemplo1/providers/Microsoft.Network/virtualNetworks/vm-ollama-h100-vnet/subnets/vm-ollama-h100-subnet"
```

### Paso 2: Valores de dependencias capturados — 2026-07-07 19:17:51
```
resource_group_name = rg-llm-lab-ejemplo1
location            = eastus2
subnet_id           = /subscriptions/3e9dda65-6318-441d-9cd1-323be07d7a58/resourceGroups/rg-llm-lab-ejemplo1/providers/Microsoft.Network/virtualNetworks/vm-ollama-h100-vnet/subnets/vm-ollama-h100-subnet
public_ip_id        = /subscriptions/3e9dda65-6318-441d-9cd1-323be07d7a58/resourceGroups/rg-llm-lab-ejemplo1/providers/Microsoft.Network/publicIPAddresses/vm-ollama-h100-pip
public_ip_address   = 137.116.36.202
```

### Paso 3: fmt / validate / plan — 2026-07-07 19:18:10
```
[0m[1mInitializing provider plugins found in the configuration...[0m
- Reusing previous version of hashicorp/azurerm from the dependency lock file
- Using previously-installed hashicorp/azurerm v4.80.0

[0m[1mInitializing the backend...[0m



[0m[1m[32mTerraform has been successfully initialized![0m[32m[0m
[0m[32m
You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.[0m
--- fmt -check ---
--- validate ---
[32m[1mSuccess![0m The configuration is valid.
[0m
--- plan ---

Terraform used the selected providers to generate the following execution
plan. Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # azurerm_linux_virtual_machine.main will be created
  + resource "azurerm_linux_virtual_machine" "main" {
      + admin_username                                         = "azureuser"
      + allow_extension_operations                             = (known after apply)
      + bypass_platform_safety_checks_on_user_schedule_enabled = false
      + computer_name                                          = (known after apply)
      + disable_password_authentication                        = true
      + disk_controller_type                                   = (known after apply)
      + extensions_time_budget                                 = "PT1H30M"
      + id                                                     = (known after apply)
      + location                                               = "eastus2"
      + max_bid_price                                          = -1
      + name                                                   = "vm-ollama-h100"
      + network_interface_ids                                  = (known after apply)
      + os_managed_disk_id                                     = (known after apply)
      + patch_assessment_mode                                  = (known after apply)
      + patch_mode                                             = (known after apply)
      + platform_fault_domain                                  = -1
      + priority                                               = "Regular"
      + private_ip_address                                     = (known after apply)
      + private_ip_addresses                                   = (known after apply)
      + provision_vm_agent                                     = (known after apply)
      + public_ip_address                                      = (known after apply)
      + public_ip_addresses                                    = (known after apply)
      + resource_group_name                                    = "rg-llm-lab-ejemplo1"
      + size                                                   = "Standard_NC40ads_H100_v5"
      + tags                                                   = {
          + "environment" = "Laboratorio"
          + "owner"       = "Andres Morera"
          + "project"     = "ModeloLLMOpensource"
        }
      + virtual_machine_id                                     = (known after apply)
      + vm_agent_platform_updates_enabled                      = (known after apply)

      + admin_ssh_key {
          + public_key = <<-EOT
                ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDQdmFiqiALoNFQthVBxIP6B/XRIGVRr5ankxnGTv4enfGKJEarYILgfnore8AH1fOqYm13ENWc9ZK2aj07iWEVjuc5JSb1WL2JStiiKea4hXTtyOoYBEguhBN1v66I+6Gs5afgFx/pVJ+ewe6Wq00gKeo4VAJg/q7HxjFA/ZOado6dEjKIcLzSHuKtpuqp6HgIDc/cIaajNhfDsofQXUFzMgB6gzLYrujdLxjCreIdk5U1wohLCvFE54TfGTpxGgKDOl8VLdr61Bkp1cdG8WD3u7OP7BpnhGp8wUV7uKggAJgrSfatud1Ye7vbG82/nVC93oDc0NhoezYZKKv2gXFLzy6VSbzn/d5egY2k+KnVN5Nxt8Y0waLtttOa6l4F9nD6QCPi69hWKDlUxDNVhbwPGIShObxIAlrT5Hiug0DRgEEYn9EA265IVBTmCrmK+6PHsx9WuL4ZoxUgqI2mkijNzjVbdgsN+tAAlT00A67y1idGulgV2dH+MKWOGH19oIGwDF0BaNu0A3weXE7rqnynjdxhOhEAYIThYx9gbtznR798Cn2gxs4tjQDn9bfdOuNSV7jplWYs/X90GdNlOhP+ZKqpni43iB0B8bJpGrthlF8zcAwNwpyjuB/ATNmllI98Ev4nB2ZnivSFbDkpMdmWPXoygj8iJnJ0/pApqIbUdQ== azureuser@ollama-h100
            EOT
          + username   = "azureuser"
        }

      + os_disk {
          + caching                   = "ReadWrite"
          + disk_size_gb              = 64
          + id                        = (known after apply)
          + name                      = (known after apply)
          + storage_account_type      = "StandardSSD_LRS"
          + write_accelerator_enabled = false
        }

      + source_image_reference {
          + offer     = "ubuntu-hpc"
          + publisher = "microsoft-dsvm"
          + sku       = "2404"
          + version   = "latest"
        }

      + termination_notification (known after apply)
    }

  # azurerm_network_interface.main will be created
  + resource "azurerm_network_interface" "main" {
      + accelerated_networking_enabled = false
      + applied_dns_servers            = (known after apply)
      + id                             = (known after apply)
      + internal_domain_name_suffix    = (known after apply)
      + ip_forwarding_enabled          = false
      + location                       = "eastus2"
      + mac_address                    = (known after apply)
      + name                           = "vm-ollama-h100-nic"
      + private_ip_address             = (known after apply)
      + private_ip_addresses           = (known after apply)
      + resource_group_name            = "rg-llm-lab-ejemplo1"
      + tags                           = {
          + "environment" = "Laboratorio"
          + "owner"       = "Andres Morera"
          + "project"     = "ModeloLLMOpensource"
        }
      + virtual_machine_id             = (known after apply)

      + ip_configuration {
          + gateway_load_balancer_frontend_ip_configuration_id = (known after apply)
          + name                                               = "internal"
          + primary                                            = (known after apply)
          + private_ip_address                                 = (known after apply)
          + private_ip_address_allocation                      = "Dynamic"
          + private_ip_address_version                         = "IPv4"
          + public_ip_address_id                               = "/subscriptions/3e9dda65-6318-441d-9cd1-323be07d7a58/resourceGroups/rg-llm-lab-ejemplo1/providers/Microsoft.Network/publicIPAddresses/vm-ollama-h100-pip"
          + subnet_id                                          = "/subscriptions/3e9dda65-6318-441d-9cd1-323be07d7a58/resourceGroups/rg-llm-lab-ejemplo1/providers/Microsoft.Network/virtualNetworks/vm-ollama-h100-vnet/subnets/vm-ollama-h100-subnet"
        }
    }

Plan: 2 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + admin_username = "azureuser"
  + vm_name        = "vm-ollama-h100"
  + vm_public_ip   = "137.116.36.202"

─────────────────────────────────────────────────────────────────────────────

Note: You didn't use the -out option to save this plan, so Terraform can't
guarantee to take exactly these actions if you run "terraform apply" now.
```

### Paso 4: terraform apply real — 2026-07-07 19:18:28
```

Terraform used the selected providers to generate the following execution
plan. Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # azurerm_linux_virtual_machine.main will be created
  + resource "azurerm_linux_virtual_machine" "main" {
      + admin_username                                         = "azureuser"
      + allow_extension_operations                             = (known after apply)
      + bypass_platform_safety_checks_on_user_schedule_enabled = false
      + computer_name                                          = (known after apply)
      + disable_password_authentication                        = true
      + disk_controller_type                                   = (known after apply)
      + extensions_time_budget                                 = "PT1H30M"
      + id                                                     = (known after apply)
      + location                                               = "eastus2"
      + max_bid_price                                          = -1
      + name                                                   = "vm-ollama-h100"
      + network_interface_ids                                  = (known after apply)
      + os_managed_disk_id                                     = (known after apply)
      + patch_assessment_mode                                  = (known after apply)
      + patch_mode                                             = (known after apply)
      + platform_fault_domain                                  = -1
      + priority                                               = "Regular"
      + private_ip_address                                     = (known after apply)
      + private_ip_addresses                                   = (known after apply)
      + provision_vm_agent                                     = (known after apply)
      + public_ip_address                                      = (known after apply)
      + public_ip_addresses                                    = (known after apply)
      + resource_group_name                                    = "rg-llm-lab-ejemplo1"
      + size                                                   = "Standard_NC40ads_H100_v5"
      + tags                                                   = {
          + "environment" = "Laboratorio"
          + "owner"       = "Andres Morera"
          + "project"     = "ModeloLLMOpensource"
        }
      + virtual_machine_id                                     = (known after apply)
      + vm_agent_platform_updates_enabled                      = (known after apply)

      + admin_ssh_key {
          + public_key = <<-EOT
                ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDQdmFiqiALoNFQthVBxIP6B/XRIGVRr5ankxnGTv4enfGKJEarYILgfnore8AH1fOqYm13ENWc9ZK2aj07iWEVjuc5JSb1WL2JStiiKea4hXTtyOoYBEguhBN1v66I+6Gs5afgFx/pVJ+ewe6Wq00gKeo4VAJg/q7HxjFA/ZOado6dEjKIcLzSHuKtpuqp6HgIDc/cIaajNhfDsofQXUFzMgB6gzLYrujdLxjCreIdk5U1wohLCvFE54TfGTpxGgKDOl8VLdr61Bkp1cdG8WD3u7OP7BpnhGp8wUV7uKggAJgrSfatud1Ye7vbG82/nVC93oDc0NhoezYZKKv2gXFLzy6VSbzn/d5egY2k+KnVN5Nxt8Y0waLtttOa6l4F9nD6QCPi69hWKDlUxDNVhbwPGIShObxIAlrT5Hiug0DRgEEYn9EA265IVBTmCrmK+6PHsx9WuL4ZoxUgqI2mkijNzjVbdgsN+tAAlT00A67y1idGulgV2dH+MKWOGH19oIGwDF0BaNu0A3weXE7rqnynjdxhOhEAYIThYx9gbtznR798Cn2gxs4tjQDn9bfdOuNSV7jplWYs/X90GdNlOhP+ZKqpni43iB0B8bJpGrthlF8zcAwNwpyjuB/ATNmllI98Ev4nB2ZnivSFbDkpMdmWPXoygj8iJnJ0/pApqIbUdQ== azureuser@ollama-h100
            EOT
          + username   = "azureuser"
        }

      + os_disk {
          + caching                   = "ReadWrite"
          + disk_size_gb              = 64
          + id                        = (known after apply)
          + name                      = (known after apply)
          + storage_account_type      = "StandardSSD_LRS"
          + write_accelerator_enabled = false
        }

      + source_image_reference {
          + offer     = "ubuntu-hpc"
          + publisher = "microsoft-dsvm"
          + sku       = "2404"
          + version   = "latest"
        }

      + termination_notification (known after apply)
    }

  # azurerm_network_interface.main will be created
  + resource "azurerm_network_interface" "main" {
      + accelerated_networking_enabled = false
      + applied_dns_servers            = (known after apply)
      + id                             = (known after apply)
      + internal_domain_name_suffix    = (known after apply)
      + ip_forwarding_enabled          = false
      + location                       = "eastus2"
      + mac_address                    = (known after apply)
      + name                           = "vm-ollama-h100-nic"
      + private_ip_address             = (known after apply)
      + private_ip_addresses           = (known after apply)
      + resource_group_name            = "rg-llm-lab-ejemplo1"
      + tags                           = {
          + "environment" = "Laboratorio"
          + "owner"       = "Andres Morera"
          + "project"     = "ModeloLLMOpensource"
        }
      + virtual_machine_id             = (known after apply)

      + ip_configuration {
          + gateway_load_balancer_frontend_ip_configuration_id = (known after apply)
          + name                                               = "internal"
          + primary                                            = (known after apply)
          + private_ip_address                                 = (known after apply)
          + private_ip_address_allocation                      = "Dynamic"
          + private_ip_address_version                         = "IPv4"
          + public_ip_address_id                               = "/subscriptions/3e9dda65-6318-441d-9cd1-323be07d7a58/resourceGroups/rg-llm-lab-ejemplo1/providers/Microsoft.Network/publicIPAddresses/vm-ollama-h100-pip"
          + subnet_id                                          = "/subscriptions/3e9dda65-6318-441d-9cd1-323be07d7a58/resourceGroups/rg-llm-lab-ejemplo1/providers/Microsoft.Network/virtualNetworks/vm-ollama-h100-vnet/subnets/vm-ollama-h100-subnet"
        }
    }

Plan: 2 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + admin_username = "azureuser"
  + vm_name        = "vm-ollama-h100"
  + vm_public_ip   = "137.116.36.202"
azurerm_network_interface.main: Creating...
azurerm_network_interface.main: Creation complete after 4s [id=/subscriptions/3e9dda65-6318-441d-9cd1-323be07d7a58/resourceGroups/rg-llm-lab-ejemplo1/providers/Microsoft.Network/networkInterfaces/vm-ollama-h100-nic]
azurerm_linux_virtual_machine.main: Creating...
azurerm_linux_virtual_machine.main: Still creating... [00m10s elapsed]
azurerm_linux_virtual_machine.main: Still creating... [00m20s elapsed]
azurerm_linux_virtual_machine.main: Still creating... [00m30s elapsed]
azurerm_linux_virtual_machine.main: Still creating... [00m40s elapsed]
azurerm_linux_virtual_machine.main: Still creating... [00m50s elapsed]
azurerm_linux_virtual_machine.main: Creation complete after 51s [id=/subscriptions/3e9dda65-6318-441d-9cd1-323be07d7a58/resourceGroups/rg-llm-lab-ejemplo1/providers/Microsoft.Compute/virtualMachines/vm-ollama-h100]

Apply complete! Resources: 2 added, 0 changed, 0 destroyed.

Outputs:

admin_username = "azureuser"
vm_name = "vm-ollama-h100"
vm_public_ip = "137.116.36.202"
```

### Paso 6a: Eliminar NIC manualmente para probar reconciliación — 2026-07-07 19:21:42
```
Eliminando NIC: vm-ollama-h100-nic en RG: rg-llm-lab-ejemplo1
```

### Paso 6a: Eliminar NIC manualmente para probar reconciliación — 2026-07-07 19:23:12
```
Eliminando NIC: vm-ollama-h100-nic en RG: rg-llm-lab-ejemplo1
```

### Paso 6b: terraform plan tras eliminar la NIC (debe detectar el drift) — 2026-07-07 19:23:36
```
azurerm_network_interface.main: Refreshing state... [id=/subscriptions/3e9dda65-6318-441d-9cd1-323be07d7a58/resourceGroups/rg-llm-lab-ejemplo1/providers/Microsoft.Network/networkInterfaces/vm-ollama-h100-nic]
azurerm_linux_virtual_machine.main: Refreshing state... [id=/subscriptions/3e9dda65-6318-441d-9cd1-323be07d7a58/resourceGroups/rg-llm-lab-ejemplo1/providers/Microsoft.Compute/virtualMachines/vm-ollama-h100]

No changes. Your infrastructure matches the configuration.

Terraform has compared your real infrastructure against your configuration
and found no differences, so no changes are needed.
```
### Paso 6c: terraform apply para reconciliar (Requirement 8.3) — 2026-07-07 19:23:48
```
azurerm_network_interface.main: Refreshing state... [id=/subscriptions/3e9dda65-6318-441d-9cd1-323be07d7a58/resourceGroups/rg-llm-lab-ejemplo1/providers/Microsoft.Network/networkInterfaces/vm-ollama-h100-nic]
azurerm_linux_virtual_machine.main: Refreshing state... [id=/subscriptions/3e9dda65-6318-441d-9cd1-323be07d7a58/resourceGroups/rg-llm-lab-ejemplo1/providers/Microsoft.Compute/virtualMachines/vm-ollama-h100]

No changes. Your infrastructure matches the configuration.

Terraform has compared your real infrastructure against your configuration
and found no differences, so no changes are needed.

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

Outputs:

admin_username = "azureuser"
vm_name = "vm-ollama-h100"
vm_public_ip = "137.116.36.202"
```

### Paso 7: Outputs finales — 2026-07-07 19:24:15
```
admin_username = "azureuser"
vm_name = "vm-ollama-h100"
vm_public_ip = "137.116.36.202"
```

### Paso 7b: Apagar la VM (az vm deallocate) — 2026-07-07 19:24:39
```
```

## Veredicto final de esta corrida — 2026-07-07 19:25:43
- Requirement 8.1 (idempotencia post-apply): **PASS**
- Requirement 8.3 (reconciliación de recurso eliminado): **PASS** — Nota: el Paso 6a (eliminar NIC manualmente) se ejecutó con la VM aún encendida (el `az vm deallocate` del Paso 7b fue posterior); Azure no permite borrar una NIC adjunta a una VM en ejecución, por lo que el resultado "No changes" del Paso 6b es ambiguo entre "Terraform reconcilió" y "la NIC nunca llegó a borrarse". Aceptado como PASS por decisión explícita del usuario (2026-07-07), sin volver a ejecutar la prueba con la VM desasociada/apagada.
- Requirement 6 (outputs correctos): **PASS**
- Decisión: **GO**

