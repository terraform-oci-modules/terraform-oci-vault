################################################################################
# Mock unit tests: fast, free, no real OCI resources.
#
# Turning key auto-rotation off. is_auto_rotation_enabled and
# auto_key_rotation_details are optional and computed in the OCI provider, so
# sending null (or no block) keeps the previous value: Terraform plans no change
# and rotation stays on. Runs are sequential and share state: the first enables
# rotation, the next ones change the config the way a user would. Uses
# command = apply against the mock so each run starts from the previous state.
# Run on its own:
#   terraform test -filter=tests/key_rotation.tftest.hcl
################################################################################

mock_provider "oci" {}

variables {
  compartment_id = "ocid1.compartment.oc1..aaaaaaaaunitcompartment"
  vault          = { vault_type = "VIRTUAL_PRIVATE" }
}

run "rotation_on" {
  command = apply

  variables {
    keys = {
      k1 = {
        key_shape                 = { algorithm = "AES", length = 32 }
        rotation_interval_in_days = 90
      }
    }
  }

  assert {
    condition     = oci_kms_key.this["k1"].is_auto_rotation_enabled == true
    error_message = "rotation_interval_in_days must enable auto-rotation"
  }
}

run "removing_the_interval_turns_rotation_off" {
  command = plan

  variables {
    keys = {
      k1 = { key_shape = { algorithm = "AES", length = 32 } }
    }
  }

  assert {
    condition     = oci_kms_key.this["k1"].is_auto_rotation_enabled == false
    error_message = "removing rotation_interval_in_days must plan is_auto_rotation_enabled = false, not keep true"
  }
}

run "explicit_false_turns_rotation_off" {
  command = plan

  variables {
    keys = {
      k1 = {
        key_shape                 = { algorithm = "AES", length = 32 }
        is_auto_rotation_enabled  = false
        rotation_interval_in_days = 90
      }
    }
  }

  assert {
    condition     = oci_kms_key.this["k1"].is_auto_rotation_enabled == false
    error_message = "is_auto_rotation_enabled = false must win over a configured interval"
  }
}

run "key_without_rotation_sends_false" {
  command = plan

  variables {
    keys = {
      k1 = { key_shape = { algorithm = "AES", length = 32 } }
      k2 = { key_shape = { algorithm = "AES", length = 32 } }
    }
  }

  assert {
    condition     = oci_kms_key.this["k2"].is_auto_rotation_enabled == false
    error_message = "a new key without rotation settings must send is_auto_rotation_enabled = false, not null"
  }
}
