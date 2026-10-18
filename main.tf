locals {
  create = var.create

  # Create a vault unless the caller passed an existing one to reuse.
  create_vault = local.create && var.vault_id == null

  vault_id = local.create_vault ? one(oci_kms_vault.this[*].id) : var.vault_id

  # oci_kms_key requires the vault's management endpoint. Take it from the created
  # vault, or read it from the existing vault via the data source.
  management_endpoint = local.create_vault ? one(oci_kms_vault.this[*].management_endpoint) : try(data.oci_kms_vault.existing[0].management_endpoint, null)
  crypto_endpoint     = local.create_vault ? one(oci_kms_vault.this[*].crypto_endpoint) : try(data.oci_kms_vault.existing[0].crypto_endpoint, null)
}

data "oci_kms_vault" "existing" {
  count = local.create && var.vault_id != null ? 1 : 0

  vault_id = var.vault_id

  lifecycle {
    # A precondition, not a variable validation: Terraform 1.7 validations can
    # only refer to their own variable.
    precondition {
      condition     = var.replica_region == null
      error_message = "replica_region cannot be used with vault_id: the module only replicates a vault it creates."
    }
  }
}

################################################################################
# Vault
################################################################################

resource "oci_kms_vault" "this" {
  count = local.create_vault ? 1 : 0

  compartment_id   = var.compartment_id
  display_name     = var.vault.display_name
  vault_type       = var.vault.vault_type
  time_of_deletion = var.vault.time_of_deletion

  freeform_tags = merge(var.tags, var.vault.tags)
  defined_tags  = merge(var.defined_tags, var.vault.defined_tags)

  dynamic "timeouts" {
    for_each = var.vault.timeouts != null ? [var.vault.timeouts] : []
    content {
      create = timeouts.value.create
      update = timeouts.value.update
      delete = timeouts.value.delete
    }
  }

  lifecycle {
    precondition {
      condition     = var.replica_region == null || var.vault.vault_type == "VIRTUAL_PRIVATE"
      error_message = "replica_region requires vault.vault_type = \"VIRTUAL_PRIVATE\" (OCI only replicates virtual private vaults)."
    }
    # OCI auto-injects Oracle-Tags (CreatedBy/CreatedOn) into defined_tags and can
    # apply compartment tag defaults; ignoring both tag maps avoids perpetual
    # drift. Matches terraform-oci-iam / terraform-oci-vcn. Trade-off: tag changes
    # after create are not reconciled by this module.
    ignore_changes = [defined_tags, freeform_tags]
  }
}

resource "oci_kms_vault_replication" "this" {
  count = local.create_vault && var.replica_region != null ? 1 : 0

  vault_id       = oci_kms_vault.this[0].id
  replica_region = var.replica_region
}

################################################################################
# Keys
################################################################################

resource "oci_kms_key" "this" {
  for_each = local.create ? var.keys : {}

  compartment_id      = var.compartment_id
  display_name        = coalesce(each.value.display_name, each.key)
  management_endpoint = local.management_endpoint
  protection_mode     = each.value.protection_mode
  time_of_deletion    = each.value.time_of_deletion

  # Enable auto-rotation implicitly when an interval is given, so a lone
  # rotation_interval_in_days does not produce a schedule with the flag unset.
  # Always an explicit true/false, never null: the provider treats null as
  # "keep the current value", so removing the interval left rotation on.
  is_auto_rotation_enabled = coalesce(each.value.is_auto_rotation_enabled, each.value.rotation_interval_in_days != null)

  key_shape {
    algorithm = each.value.key_shape.algorithm
    length    = each.value.key_shape.length
    curve_id  = each.value.key_shape.curve_id
  }

  dynamic "auto_key_rotation_details" {
    for_each = each.value.rotation_interval_in_days != null ? [each.value.rotation_interval_in_days] : []
    content {
      rotation_interval_in_days = auto_key_rotation_details.value
    }
  }

  freeform_tags = merge(var.tags, each.value.tags)
  defined_tags  = merge(var.defined_tags, each.value.defined_tags)

  dynamic "timeouts" {
    for_each = each.value.timeouts != null ? [each.value.timeouts] : []
    content {
      create = timeouts.value.create
      update = timeouts.value.update
      delete = timeouts.value.delete
    }
  }

  lifecycle {
    ignore_changes = [defined_tags, freeform_tags]
  }
}
