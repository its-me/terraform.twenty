# Shared Cloud SQL instance for all app deployments in this project. This is the
# owning caller (create = true); other apps (e.g. terraform.outline) point at the
# same `name` with create = false to read the instance back instead of creating
# their own. Each caller still manages its own database/user via the module.
module "postgresql" {
  source = "git::https://github.com/its-me/terraform.module.postgresql.git?ref=main"

  project_id        = var.project_id
  region            = var.region
  name              = var.db_instance_name
  create            = true
  network_id        = module.network.network_id
  tier              = var.db_tier
  availability_type = var.db_availability_type
  disk_size_gb      = var.db_disk_size_gb
  labels            = var.labels

  database_name = var.db_name
  database_user = var.db_user

  depends_on = [module.network]
}
