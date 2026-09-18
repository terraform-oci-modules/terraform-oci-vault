terraform {
  required_version = ">= 1.7"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 6.9.0" # auto_key_rotation_details, VIRTUAL_PRIVATE vault replication
    }
  }
}
