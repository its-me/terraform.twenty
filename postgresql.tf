# Shared Cloud SQL instance for all app deployments in this project. Owned and
# created by terraform.infrastructure; this reads the same `name` back (create =
# false) instead of creating its own, managing its own database/user on top.
module "postgresql" {
  source = "git::https://github.com/its-me/terraform.module.postgresql.git?ref=v0.1.5"

  project_id = var.project_id
  region     = var.region
  name       = var.db_instance_name
  create     = false

  database_name = var.db_name
  database_user = var.db_user
}
