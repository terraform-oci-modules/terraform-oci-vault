module "wrapper" {
  source = "../"

  for_each = var.items

  compartment_id = try(each.value.compartment_id, var.defaults.compartment_id)
  create         = try(each.value.create, var.defaults.create, true)
  defined_tags   = try(each.value.defined_tags, var.defaults.defined_tags, {})
  keys           = try(each.value.keys, var.defaults.keys, {})
  replica_region = try(each.value.replica_region, var.defaults.replica_region, null)
  tags           = try(each.value.tags, var.defaults.tags, {})
  vault          = try(each.value.vault, var.defaults.vault, {})
  vault_id       = try(each.value.vault_id, var.defaults.vault_id, null)
}
