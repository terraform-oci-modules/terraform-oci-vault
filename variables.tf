################################################################################
# Core / Control
################################################################################

variable "create" {
  description = "Controls if resources should be created (master switch - affects all resources)"
  type        = bool
  default     = true
}

variable "compartment_id" {
  description = "The OCID of the compartment that holds the vault and the keys"
  type        = string

  validation {
    condition     = can(regex("^ocid1\\.(compartment|tenancy)\\.[a-z0-9.]+", var.compartment_id))
    error_message = "compartment_id must be a valid OCID starting with ocid1.compartment or ocid1.tenancy."
  }
}

variable "tags" {
  description = "A map of freeform tags to add to the vault and every key. Applied at create time only (changes are ignored, matching the sibling OCI modules)"
  type        = map(string)
  default     = {}
  nullable    = false
}

variable "defined_tags" {
  description = "A map of defined tags (namespace.key = value) to add to the vault and every key. Applied at create time only (changes are ignored, matching the sibling OCI modules)"
  type        = map(string)
  default     = {}
  nullable    = false
}

################################################################################
# Vault
################################################################################

variable "vault_id" {
  description = <<-EOT
    OCID of an existing vault to create the keys in. When set, the module does
    not create a vault (the `vault` variable and `replica_region` are ignored)
    and manages only the keys, reading the vault's management endpoint from a
    data source.
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.vault_id == null ? true : can(regex("^ocid1\\.vault\\.[a-z0-9.-]+", var.vault_id))
    error_message = "vault_id must be a valid vault OCID starting with ocid1.vault."
  }
}

variable "vault" {
  description = <<-EOT
    Configuration for the vault to create. Ignored when `vault_id` is set.
      display_name     : user-friendly name for the vault.
      vault_type       : DEFAULT (shared HSM partitions) or VIRTUAL_PRIVATE
                         (dedicated partition, separately billed). Cannot be
                         changed after create.
      time_of_deletion : RFC 3339 timestamp used only on `terraform destroy` -
                         the vault is scheduled for deletion at this time instead
                         of the OCI default of 30 days out. OCI requires it to be
                         7 to 30 days from when destroy runs.
      timeouts         : create / update / delete timeout overrides.
      tags             : freeform tags for the vault, merged over var.tags.
      defined_tags     : defined tags for the vault, merged over var.defined_tags.
  EOT
  type = object({
    display_name     = optional(string, "vault")
    vault_type       = optional(string, "DEFAULT")
    time_of_deletion = optional(string)
    timeouts = optional(object({
      create = optional(string)
      update = optional(string)
      delete = optional(string)
    }))
    tags         = optional(map(string), {})
    defined_tags = optional(map(string), {})
  })
  default  = {}
  nullable = false

  validation {
    condition     = contains(["DEFAULT", "VIRTUAL_PRIVATE"], var.vault.vault_type)
    error_message = "vault.vault_type must be DEFAULT or VIRTUAL_PRIVATE."
  }
  validation {
    condition     = var.vault.time_of_deletion == null || can(regex("^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(\\.\\d+)?(Z|[+-]\\d{2}:\\d{2})$", coalesce(var.vault.time_of_deletion, "x")))
    error_message = "vault.time_of_deletion must be an RFC 3339 timestamp (e.g. 2026-09-12T00:00:00Z)."
  }
}

variable "replica_region" {
  description = <<-EOT
    Identifier of a subscribed region (e.g. us-phoenix-1) to replicate the vault
    into. Only used when the module creates the vault. OCI only replicates
    VIRTUAL_PRIVATE vaults, so this requires vault.vault_type = "VIRTUAL_PRIVATE".
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.replica_region == null || var.vault_id == null
    error_message = "replica_region cannot be used with vault_id: the module only replicates a vault it creates."
  }
  validation {
    condition     = var.replica_region == null || var.vault.vault_type == "VIRTUAL_PRIVATE"
    error_message = "replica_region requires vault.vault_type = \"VIRTUAL_PRIVATE\" (OCI only replicates virtual private vaults)."
  }
}

################################################################################
# Keys
################################################################################

variable "keys" {
  description = <<-EOT
    Map of master encryption keys to create in the vault, keyed by name.
      display_name              : defaults to the map key.
      key_shape.algorithm       : AES, RSA, or ECDSA.
      key_shape.length          : key size in BYTES - AES 16/24/32, RSA 256/384/512, ECDSA 32/48/66.
      key_shape.curve_id        : NIST_P256 / NIST_P384 / NIST_P521 - required for ECDSA.
      protection_mode           : HSM (default) or SOFTWARE. Cannot be changed after create.
      is_auto_rotation_enabled  : enable automatic key rotation. Defaults to true
                                  when rotation_interval_in_days is set.
      rotation_interval_in_days : 60-365; required when is_auto_rotation_enabled is true.
      time_of_deletion          : RFC 3339 timestamp used only on `terraform
                                  destroy` - the key is scheduled for deletion at
                                  this time instead of the OCI default of 30 days
                                  out. OCI requires 7 to 30 days from when destroy
                                  runs.
      timeouts                  : create / update / delete timeout overrides.
      tags / defined_tags       : per-key tags, merged over var.tags / var.defined_tags.
  EOT
  type = map(object({
    display_name = optional(string)
    key_shape = object({
      algorithm = string
      length    = number
      curve_id  = optional(string)
    })
    protection_mode           = optional(string, "HSM")
    is_auto_rotation_enabled  = optional(bool)
    rotation_interval_in_days = optional(number)
    time_of_deletion          = optional(string)
    timeouts = optional(object({
      create = optional(string)
      update = optional(string)
      delete = optional(string)
    }))
    tags         = optional(map(string), {})
    defined_tags = optional(map(string), {})
  }))
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for k, v in var.keys : can(regex("^[a-zA-Z0-9._-]{1,100}$", k))])
    error_message = "Each key name (map key) must be 1-100 characters of letters, digits, dot, underscore, or hyphen."
  }
  validation {
    condition     = alltrue([for k, v in var.keys : contains(["AES", "RSA", "ECDSA"], v.key_shape.algorithm)])
    error_message = "keys[*].key_shape.algorithm must be one of AES, RSA, ECDSA."
  }
  validation {
    condition     = alltrue([for k, v in var.keys : v.key_shape.algorithm != "AES" || contains([16, 24, 32], v.key_shape.length)])
    error_message = "AES keys must have key_shape.length 16, 24, or 32 (bytes)."
  }
  validation {
    condition     = alltrue([for k, v in var.keys : v.key_shape.algorithm != "RSA" || contains([256, 384, 512], v.key_shape.length)])
    error_message = "RSA keys must have key_shape.length 256, 384, or 512 (bytes)."
  }
  validation {
    condition     = alltrue([for k, v in var.keys : v.key_shape.algorithm != "ECDSA" || contains([32, 48, 66], v.key_shape.length)])
    error_message = "ECDSA keys must have key_shape.length 32, 48, or 66 (bytes)."
  }
  validation {
    condition = alltrue([
      for k, v in var.keys :
      v.key_shape.algorithm != "ECDSA" || contains(["NIST_P256", "NIST_P384", "NIST_P521"], coalesce(v.key_shape.curve_id, "none"))
    ])
    error_message = "ECDSA keys must set key_shape.curve_id to NIST_P256, NIST_P384, or NIST_P521."
  }
  validation {
    condition     = alltrue([for k, v in var.keys : v.key_shape.algorithm == "ECDSA" || v.key_shape.curve_id == null])
    error_message = "key_shape.curve_id is only valid for ECDSA keys."
  }
  validation {
    condition     = alltrue([for k, v in var.keys : contains(["HSM", "SOFTWARE"], v.protection_mode)])
    error_message = "keys[*].protection_mode must be HSM or SOFTWARE."
  }
  validation {
    condition = alltrue([
      for k, v in var.keys :
      v.rotation_interval_in_days == null || (v.rotation_interval_in_days >= 60 && v.rotation_interval_in_days <= 365)
    ])
    error_message = "keys[*].rotation_interval_in_days must be between 60 and 365."
  }
  validation {
    condition = alltrue([
      for k, v in var.keys :
      coalesce(v.is_auto_rotation_enabled, false) == false || v.rotation_interval_in_days != null
    ])
    error_message = "keys[*].is_auto_rotation_enabled = true requires rotation_interval_in_days to be set."
  }
  validation {
    condition = alltrue([
      for k, v in var.keys :
      v.time_of_deletion == null || can(regex("^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(\\.\\d+)?(Z|[+-]\\d{2}:\\d{2})$", coalesce(v.time_of_deletion, "x")))
    ])
    error_message = "keys[*].time_of_deletion must be an RFC 3339 timestamp (e.g. 2026-09-12T00:00:00Z)."
  }
}
