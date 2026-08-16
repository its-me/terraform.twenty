# Shared Memorystore Redis instance for all app deployments in this project. This is
# the owning caller (create = true); other apps (e.g. terraform.outline) point at the
# same `name` with create = false to read the instance back instead of creating their
# own. Each caller isolates its keys via its own var.redis_db index.
module "redis" {
  source = "git::https://github.com/its-me/terraform.module.redis.git?ref=main"

  project_id = var.project_id
  region     = var.region
  name       = var.redis_instance_name
  create     = true
  network_id = module.network.network_id

  tier           = var.redis_tier
  memory_size_gb = var.redis_memory_size_gb
  labels         = var.labels

  depends_on = [module.network]
}
