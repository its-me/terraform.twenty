# Shared Memorystore Redis instance for all app deployments in this project. Owned
# and created by terraform.infrastructure; this reads the same `name` back (create =
# false) instead of creating its own. Keys are isolated via var.redis_db.
module "redis" {
  source = "git::https://github.com/its-me/terraform.module.redis.git?ref=v0.1.0"

  project_id = var.project_id
  region     = var.region
  name       = var.redis_instance_name
  create     = false
}
