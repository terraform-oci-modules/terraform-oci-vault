provider "oci" {}

locals {
  name = "ex-complete"

  tags = {
    Example    = local.name
    GithubRepo = "terraform-oci-vault"
    GithubOrg  = "terraform-oci-modules"
  }
}

################################################################################
# Vault module - DEFAULT vault with several keys
################################################################################

module "vault" {
  source = "../../"

  compartment_id = var.compartment_id

  vault = {
    display_name = local.name
    vault_type   = "DEFAULT"
    tags         = { Tier = "shared" }
  }

  keys = {
    # Symmetric key for envelope encryption, HSM-protected, auto-rotated yearly.
    "${local.name}-data" = {
      key_shape = {
        algorithm = "AES"
        length    = 32
      }
      is_auto_rotation_enabled  = true
      rotation_interval_in_days = 365
      tags                      = { Purpose = "envelope-encryption" }
    }

    # RSA key for signing, software-protected (cheaper, higher throughput).
    "${local.name}-signing" = {
      key_shape = {
        algorithm = "RSA"
        length    = 512
      }
      protection_mode = "SOFTWARE"
    }

    # ECDSA signing key on the P-384 curve.
    "${local.name}-ecdsa" = {
      key_shape = {
        algorithm = "ECDSA"
        length    = 48
        curve_id  = "NIST_P384"
      }
    }
  }

  tags = local.tags
}
