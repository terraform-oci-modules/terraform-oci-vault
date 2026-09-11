variable "compartment_id" {
  description = "The OCID of the compartment to create the keys in"
  type        = string
}

variable "vault_id" {
  description = "OCID of an existing vault to create the keys in"
  type        = string
}
