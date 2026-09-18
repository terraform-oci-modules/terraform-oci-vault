variable "compartment_id" {
  description = "The OCID of the compartment to create the vault and key in"
  type        = string
}

variable "replica_region" {
  description = "A subscribed region of the tenancy to replicate the vault into (e.g. us-phoenix-1)"
  type        = string
  default     = "us-phoenix-1"
}
