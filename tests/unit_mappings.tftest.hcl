################################################################################
# Mock unit tests: fast, free, no real OCI resources.
#
# Exercises input->config mapping logic (vault create vs bring-your-own,
# key_shape passthrough, display-name defaulting, tag merging, the auto-rotation
# block, replication gating) against the module root with a mocked OCI provider.
# Every validation block has a matching reject case. Run on its own:
#   terraform test -filter=tests/unit_mappings.tftest.hcl
################################################################################

mock_provider "oci" {}

variables {
  compartment_id = "ocid1.compartment.oc1..aaaaaaaaunitcompartment"
}

# --- Vault: create vs bring-your-own ---------------------------------------

run "creates_a_vault_by_default" {
  command = plan

  variables {
    keys = {
      k1 = { key_shape = { algorithm = "AES", length = 32 } }
    }
  }

  assert {
    condition     = length(oci_kms_vault.this) == 1
    error_message = "with no vault_id the module must create a vault"
  }
  assert {
    condition     = length(data.oci_kms_vault.existing) == 0
    error_message = "the existing-vault data source must not be read when creating a vault"
  }
  assert {
    condition     = oci_kms_vault.this[0].vault_type == "DEFAULT"
    error_message = "vault_type must default to DEFAULT"
  }
  assert {
    condition     = length(oci_kms_key.this) == 1
    error_message = "keys must be created alongside the vault"
  }
}

run "bring_your_own_vault_skips_vault_creation" {
  command = plan

  variables {
    vault_id = "ocid1.vault.oc1.iad.aaaaaaaaexisting"
    keys = {
      k1 = { key_shape = { algorithm = "AES", length = 32 } }
    }
  }

  assert {
    condition     = length(oci_kms_vault.this) == 0
    error_message = "vault_id set: the module must not create a vault"
  }
  assert {
    condition     = length(data.oci_kms_vault.existing) == 1
    error_message = "vault_id set: the module must read the existing vault via the data source"
  }
  assert {
    condition     = local.vault_id == "ocid1.vault.oc1.iad.aaaaaaaaexisting"
    error_message = "local.vault_id must be the passed-in vault_id"
  }
  assert {
    condition     = length(oci_kms_key.this) == 1
    error_message = "keys must still be created against the existing vault"
  }
}

run "no_replication_resource_for_bring_your_own_vault" {
  command = plan

  variables {
    vault_id = "ocid1.vault.oc1.iad.aaaaaaaaexisting"
    keys     = {}
  }

  assert {
    condition     = length(oci_kms_vault_replication.this) == 0
    error_message = "replication is only created when the module creates the vault"
  }
}

# --- Key mapping ---------------------------------------------------------

run "key_display_name_defaults_to_map_key" {
  command = plan

  variables {
    keys = {
      billing = { key_shape = { algorithm = "AES", length = 32 } }
    }
  }

  assert {
    condition     = oci_kms_key.this["billing"].display_name == "billing"
    error_message = "display_name must default to the map key"
  }
}

run "key_explicit_display_name_wins" {
  command = plan

  variables {
    keys = {
      billing = { display_name = "billing-key-2024", key_shape = { algorithm = "AES", length = 32 } }
    }
  }

  assert {
    condition     = oci_kms_key.this["billing"].display_name == "billing-key-2024"
    error_message = "an explicit display_name must override the map key"
  }
}

run "key_shape_passes_through" {
  command = plan

  variables {
    keys = {
      ec = { key_shape = { algorithm = "ECDSA", length = 32, curve_id = "NIST_P256" } }
    }
  }

  assert {
    condition     = oci_kms_key.this["ec"].key_shape[0].algorithm == "ECDSA"
    error_message = "key_shape.algorithm must reach the resource unchanged"
  }
  assert {
    condition     = oci_kms_key.this["ec"].key_shape[0].curve_id == "NIST_P256"
    error_message = "key_shape.curve_id must reach the resource unchanged"
  }
}

run "protection_mode_defaults_to_hsm" {
  command = plan

  variables {
    keys = {
      k1 = { key_shape = { algorithm = "AES", length = 32 } }
    }
  }

  assert {
    condition     = oci_kms_key.this["k1"].protection_mode == "HSM"
    error_message = "protection_mode must default to HSM"
  }
}

run "time_of_deletion_passes_through" {
  command = plan

  variables {
    vault = {
      time_of_deletion = "2026-09-12T00:00:00Z"
    }
    keys = {
      k1 = { key_shape = { algorithm = "AES", length = 32 }, time_of_deletion = "2026-09-12T00:00:00Z" }
    }
  }

  assert {
    condition     = oci_kms_vault.this[0].time_of_deletion == "2026-09-12T00:00:00Z"
    error_message = "vault.time_of_deletion must reach the vault resource"
  }
  assert {
    condition     = oci_kms_key.this["k1"].time_of_deletion == "2026-09-12T00:00:00Z"
    error_message = "keys[*].time_of_deletion must reach the key resource"
  }
}

run "auto_rotation_block_emitted_only_with_interval" {
  command = plan

  variables {
    keys = {
      rotated = {
        key_shape                 = { algorithm = "AES", length = 32 }
        rotation_interval_in_days = 90
      }
      static = {
        key_shape = { algorithm = "AES", length = 32 }
      }
    }
  }

  assert {
    condition     = length(oci_kms_key.this["rotated"].auto_key_rotation_details) == 1
    error_message = "a key with a rotation interval must get an auto_key_rotation_details block"
  }
  assert {
    condition     = oci_kms_key.this["rotated"].auto_key_rotation_details[0].rotation_interval_in_days == 90
    error_message = "the rotation interval must reach the block"
  }
  assert {
    condition     = oci_kms_key.this["rotated"].is_auto_rotation_enabled == true
    error_message = "a lone rotation_interval_in_days must implicitly enable auto-rotation"
  }
  assert {
    condition     = length(oci_kms_key.this["static"].auto_key_rotation_details) == 0
    error_message = "a key with no rotation interval must not get the block"
  }
}

# --- Tag merge ---------------------------------------------------------

run "entry_tags_merge_over_module_tags" {
  command = plan

  variables {
    tags = { Owner = "platform", Managed = "terraform" }
    vault = {
      tags = { Owner = "security" }
    }
    keys = {
      k1 = { key_shape = { algorithm = "AES", length = 32 }, tags = { Owner = "data", Extra = "yes" } }
    }
  }

  assert {
    condition     = oci_kms_vault.this[0].freeform_tags["Owner"] == "security"
    error_message = "vault.tags must win over module-wide tags of the same key"
  }
  assert {
    condition     = oci_kms_key.this["k1"].freeform_tags["Owner"] == "data"
    error_message = "keys[*].tags must win over module-wide tags of the same key"
  }
  assert {
    condition     = oci_kms_key.this["k1"].freeform_tags["Managed"] == "terraform"
    error_message = "module-wide tags must still apply where not overridden"
  }
  assert {
    condition     = oci_kms_key.this["k1"].freeform_tags["Extra"] == "yes"
    error_message = "per-entry-only tags must be present"
  }
}

# --- Replication -------------------------------------------------------

run "replication_created_for_virtual_private_with_region" {
  command = plan

  variables {
    vault = {
      vault_type = "VIRTUAL_PRIVATE"
    }
    replica_region = "us-phoenix-1"
    keys           = {}
  }

  assert {
    condition     = length(oci_kms_vault_replication.this) == 1
    error_message = "a VIRTUAL_PRIVATE vault with replica_region must get a replication resource"
  }
  assert {
    condition     = oci_kms_vault_replication.this[0].replica_region == "us-phoenix-1"
    error_message = "replica_region must reach the replication resource"
  }
}

run "no_replication_without_region" {
  command = plan

  variables {
    vault = { vault_type = "VIRTUAL_PRIVATE" }
    keys  = {}
  }

  assert {
    condition     = length(oci_kms_vault_replication.this) == 0
    error_message = "no replica_region: no replication resource"
  }
}

# --- create = false toggle -------------------------------------------

run "create_false_makes_no_resources" {
  command = plan

  variables {
    create = false
    vault  = { vault_type = "VIRTUAL_PRIVATE" }
    keys = {
      k1 = { key_shape = { algorithm = "AES", length = 32 } }
    }
    replica_region = "us-phoenix-1"
  }

  assert {
    condition     = length(oci_kms_vault.this) == 0 && length(oci_kms_key.this) == 0 && length(oci_kms_vault_replication.this) == 0 && length(data.oci_kms_vault.existing) == 0
    error_message = "create = false must produce zero resources regardless of inputs"
  }
}

################################################################################
# Negative paths: every validation block must have a reject case.
################################################################################

run "rejects_bad_compartment_id" {
  command = plan

  variables {
    compartment_id = "not-an-ocid"
  }

  expect_failures = [var.compartment_id]
}

run "rejects_bad_vault_id" {
  command = plan

  variables {
    vault_id = "ocid1.compartment.oc1..aaaaaaaawrongtype"
  }

  expect_failures = [var.vault_id]
}

run "rejects_bad_vault_type" {
  command = plan

  variables {
    vault = { vault_type = "SUPER_PRIVATE" }
  }

  expect_failures = [var.vault]
}

run "rejects_replica_region_on_default_vault" {
  command = plan

  variables {
    replica_region = "us-phoenix-1"
  }

  expect_failures = [var.replica_region]
}

run "rejects_replica_region_with_vault_id" {
  command = plan

  variables {
    vault_id       = "ocid1.vault.oc1.iad.aaaaaaaaexisting"
    replica_region = "us-phoenix-1"
  }

  expect_failures = [var.replica_region]
}

run "rejects_bad_key_name" {
  command = plan

  variables {
    keys = {
      "bad name" = { key_shape = { algorithm = "AES", length = 32 } }
    }
  }

  expect_failures = [var.keys]
}

run "rejects_unknown_algorithm" {
  command = plan

  variables {
    keys = {
      k1 = { key_shape = { algorithm = "3DES", length = 24 } }
    }
  }

  expect_failures = [var.keys]
}

run "rejects_bad_aes_length" {
  command = plan

  variables {
    keys = {
      k1 = { key_shape = { algorithm = "AES", length = 64 } }
    }
  }

  expect_failures = [var.keys]
}

run "rejects_bad_rsa_length" {
  command = plan

  variables {
    keys = {
      k1 = { key_shape = { algorithm = "RSA", length = 2048 } }
    }
  }

  expect_failures = [var.keys]
}

run "rejects_ecdsa_without_curve" {
  command = plan

  variables {
    keys = {
      k1 = { key_shape = { algorithm = "ECDSA", length = 32 } }
    }
  }

  expect_failures = [var.keys]
}

run "rejects_curve_on_non_ecdsa" {
  command = plan

  variables {
    keys = {
      k1 = { key_shape = { algorithm = "AES", length = 32, curve_id = "NIST_P256" } }
    }
  }

  expect_failures = [var.keys]
}

run "rejects_bad_protection_mode" {
  command = plan

  variables {
    keys = {
      k1 = { key_shape = { algorithm = "AES", length = 32 }, protection_mode = "EXTERNAL" }
    }
  }

  expect_failures = [var.keys]
}

run "rejects_rotation_interval_out_of_range" {
  command = plan

  variables {
    keys = {
      k1 = {
        key_shape                 = { algorithm = "AES", length = 32 }
        is_auto_rotation_enabled  = true
        rotation_interval_in_days = 30
      }
    }
  }

  expect_failures = [var.keys]
}

run "rejects_auto_rotation_without_interval" {
  command = plan

  variables {
    keys = {
      k1 = {
        key_shape                = { algorithm = "AES", length = 32 }
        is_auto_rotation_enabled = true
      }
    }
  }

  expect_failures = [var.keys]
}

run "rejects_bad_vault_time_of_deletion" {
  command = plan

  variables {
    vault = { time_of_deletion = "next tuesday" }
  }

  expect_failures = [var.vault]
}

run "rejects_bad_key_time_of_deletion" {
  command = plan

  variables {
    keys = {
      k1 = { key_shape = { algorithm = "AES", length = 32 }, time_of_deletion = "2026-09-12" }
    }
  }

  expect_failures = [var.keys]
}
