# Mock test for examples/existing-vault. No real OCI resources, no credentials.
# The bring-your-own-vault wiring (no vault resource, data source read instead) is
# also asserted directly in tests/unit_mappings.tftest.hcl.

mock_provider "oci" {}

variables {
  compartment_id = "ocid1.compartment.oc1..aaaaaaaamockexisting"
  vault_id       = "ocid1.vault.oc1.iad.aaaaaaaamockexistingvault"
}

run "existing_vault_example" {
  command = apply

  module {
    source = "./examples/existing-vault"
  }

  assert {
    condition     = output.vault_id == "ocid1.vault.oc1.iad.aaaaaaaamockexistingvault"
    error_message = "the module must echo the passed-in vault_id"
  }
  assert {
    condition     = length(output.key_ids) == 2
    error_message = "both keys must be created in the existing vault"
  }
}
