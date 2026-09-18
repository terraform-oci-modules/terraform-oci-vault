# Mock test for examples/replicated. No real OCI resources, no credentials.

mock_provider "oci" {}

variables {
  compartment_id = "ocid1.compartment.oc1..aaaaaaaamockreplicated"
  replica_region = "us-phoenix-1"
}

run "replicated_example" {
  command = apply

  module {
    source = "./examples/replicated"
  }

  assert {
    condition     = output.vault_id != null
    error_message = "the example must expose the primary vault OCID"
  }
  assert {
    condition     = output.replica_region == "us-phoenix-1"
    error_message = "replica_region must plan through to the replication resource"
  }
  assert {
    condition     = output.key_id != null
    error_message = "the example must expose the key OCID"
  }
}
