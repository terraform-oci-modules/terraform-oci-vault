provider "oci" {}

locals {
  name = "ex-existing-vault"

  tags = {
    Example    = local.name
    GithubRepo = "terraform-oci-vault"
    GithubOrg  = "terraform-oci-modules"
  }
}

################################################################################
# Manage keys against a vault that already exists, by OCID. No vault is created.
#
# This is the shape terraform-oci-secret will use: take a vault_id (often another
# module's output) and manage resources inside that vault. The module reads the
# vault's management endpoint from a data source, so vault_id must point at a
# live vault.
#
# Note: if vault_id comes from a resource created in the same configuration, its
# OCID is unknown until that resource is applied, and Terraform cannot plan this
# module's count-based resources in one pass. Apply the vault first
# (terraform apply -target=...) or keep the vault in a separate state.
################################################################################

module "keys" {
  source = "../../"

  compartment_id = var.compartment_id
  vault_id       = var.vault_id

  keys = {
    "${local.name}-tenant-a" = {
      key_shape = {
        algorithm = "AES"
        length    = 32
      }
    }
    "${local.name}-tenant-b" = {
      key_shape = {
        algorithm = "AES"
        length    = 32
      }
    }
  }

  tags = local.tags
}
