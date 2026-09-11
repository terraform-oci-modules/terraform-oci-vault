# Mock test for examples/complete. No real OCI resources, no credentials.

mock_provider "oci" {}

variables {
  compartment_id = "ocid1.compartment.oc1..aaaaaaaamockcomplete"
}

run "complete_example" {
  command = apply

  module {
    source = "./examples/complete"
  }

  assert {
    condition     = output.vault_id != null
    error_message = "the example must expose a vault_id"
  }
  assert {
    condition     = length(output.key_ids) == 3
    error_message = "the example must create three keys"
  }
  assert {
    condition     = length(output.keys) == 3
    error_message = "the curated keys output must cover all three keys"
  }
}
