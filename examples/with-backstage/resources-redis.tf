# Create redis resource for development environments
# In-Cluster resource

module "redis" {
  # tflint-ignore: terraform_module_pinned_source
  source = "git::https://github.com/humanitec-architecture/resource-packs-in-cluster.git//humanitec-resource-defs/redis/basic?ref=main"
  prefix = "devel-"
}

resource "humanitec_resource_definition_criteria" "redis" {
  resource_definition_id = module.redis.id
  env_id                 = "development"
  env_type               = "development"

  force_delete = true
}

