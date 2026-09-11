variable "compartment_id" {
  description = "The OCID of the compartment to create the vault and key in"
  type        = string
}

variable "deletion_time" {
  description = <<-EOT
    Optional RFC 3339 timestamp. When set, `terraform destroy` schedules the
    vault and key for deletion at this time (7-30 days out) instead of the OCI
    default of 30 days. Handy for keeping test residue to the 7-day minimum:
      TF_VAR_deletion_time=$(date -u -d '+7 days' +%Y-%m-%dT%H:%M:%SZ)
  EOT
  type        = string
  default     = null
}
