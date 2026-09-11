provider "oci" {}

locals {
  name = "ex-replicated"

  tags = {
    Example    = local.name
    GithubRepo = "terraform-oci-vault"
    GithubOrg  = "terraform-oci-modules"
  }
}

################################################################################
# A VIRTUAL_PRIVATE vault replicated into a second region.
#
# OCI only replicates virtual private vaults, and a virtual private vault
# allocates a dedicated, separately-billed HSM partition. replica_region must
# name a subscribed region of the tenancy. Because of the cost and the second
# region requirement, this example is exercised with `terraform plan` only, not
# a live apply test.
################################################################################

module "vault" {
  source = "../../"

  compartment_id = var.compartment_id

  vault = {
    display_name = local.name
    vault_type   = "VIRTUAL_PRIVATE"
  }

  replica_region = var.replica_region

  keys = {
    "${local.name}-data" = {
      key_shape = {
        algorithm = "AES"
        length    = 32
      }
    }
  }

  tags = local.tags
}
