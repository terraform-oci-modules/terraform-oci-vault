# Mock test for examples/simple. No real OCI resources, no credentials.
# mock_provider resolves computed values so the example's outputs can be checked.
# Resource-shape assertions live in tests/unit_mappings.tftest.hcl.

mock_provider "oci" {}

variables {
  compartment_id = "ocid1.compartment.oc1..aaaaaaaamocksimple"
}

run "simple_example" {
  command = apply

  module {
    source = "./examples/simple"
  }

  assert {
    condition     = output.vault_id != null
    error_message = "the example must expose a vault_id"
  }
  assert {
    condition     = output.vault_management_endpoint != null
    error_message = "the example must expose the vault management endpoint"
  }
  assert {
    condition     = output.key_id != null
    error_message = "the example must expose a key_id"
  }
}
