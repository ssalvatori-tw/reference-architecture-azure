module "backstage_redis" {
  # tflint-ignore: terraform_module_pinned_source
  source = "git::https://github.com/humanitec-architecture/resource-packs-in-cluster.git//humanitec-resource-defs/redis/basic?ref=main"
  prefix = local.res_def_prefix
}

resource "humanitec_resource_definition_criteria" "backstage_redis" {
  resource_definition_id = module.backstage_redis.id

  app_id                 = humanitec_application.backstage.id
}