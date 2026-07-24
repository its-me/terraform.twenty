resource "random_password" "encryption_key" {
  length  = 32
  special = false
}

resource "random_password" "fallback_encryption_key" {
  length  = 32
  special = false
}

resource "random_password" "app_secret" {
  length  = 32
  special = false
}

locals {
  pg_database_url = "postgresql://${var.db_user}:${random_password.db.result}@${google_sql_database_instance.main.private_ip_address}:5432/${var.db_name}"
  redis_url       = "redis://${google_redis_instance.main.host}:${google_redis_instance.main.port}"

  secrets = {
    pg-database-url           = local.pg_database_url
    encryption-key            = random_password.encryption_key.result
    fallback-encryption-key   = random_password.fallback_encryption_key.result
    app-secret                = random_password.app_secret.result
    storage-secret-access-key = google_storage_hmac_key.twenty_files.secret
  }
}

resource "google_secret_manager_secret" "twenty" {
  for_each = local.secrets

  project   = var.project_id
  secret_id = "twenty-${each.key}"

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_version" "twenty" {
  for_each = local.secrets

  secret      = google_secret_manager_secret.twenty[each.key].id
  secret_data = each.value
}
