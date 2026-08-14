resource "random_password" "db" {
  length  = 32
  special = false
}

# Shared Cloud SQL instance for all app deployments in this project. This is the
# owning caller (create = true); other apps (e.g. terraform.outline) point at the
# same `name` with create = false to read the instance back instead of creating
# their own, each still managing its own database/user on top.
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

  depends_on = [module.network]
}

resource "google_sql_database" "twenty" {
  name     = var.db_name
  project  = var.project_id
  instance = module.postgresql.instance_name
}

resource "google_sql_user" "twenty" {
  name     = var.db_user
  project  = var.project_id
  instance = module.postgresql.instance_name
  password = random_password.db.result
}
