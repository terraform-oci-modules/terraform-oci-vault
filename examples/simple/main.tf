provider "oci" {}

locals {
  name = "ex-simple"

  tags = {
    Example    = local.name
    GithubRepo = "terraform-oci-vault"
    GithubOrg  = "terraform-oci-modules"
  }
}

################################################################################
# Vault module - one DEFAULT vault, one AES key
################################################################################

module "vault" {
  source = "../../"

  compartment_id = var.compartment_id

  vault = {
    display_name     = local.name
    time_of_deletion = var.deletion_time
  }

  keys = {
    "${local.name}-data" = {
      key_shape = {
        algorithm = "AES"
        length    = 32
      }
      time_of_deletion = var.deletion_time
    }
  }

  tags = local.tags
}
