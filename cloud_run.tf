locals {
  image = "docker.io/twentycrm/twenty:${var.image_tag}"

  # Plain (non-secret) env vars shared by server and worker.
  base_env = {
    REDIS_URL           = local.redis_url
    STORAGE_TYPE        = "s3"
    STORAGE_S3_REGION   = "auto"
    STORAGE_S3_NAME     = google_storage_bucket.twenty_files.name
    STORAGE_S3_ENDPOINT = "https://storage.googleapis.com"
    # Standard AWS SDK credential env vars, used by Twenty's S3 storage driver
    # against GCS's S3-interoperability API (no IAM-role credential chain on GCP).
    AWS_ACCESS_KEY_ID = google_storage_hmac_key.twenty_files.access_id
  }

  # Secret-backed env vars: map of env var name -> key into google_secret_manager_secret.twenty.
  secret_env = {
    PG_DATABASE_URL         = "pg-database-url"
    ENCRYPTION_KEY          = "encryption-key"
    FALLBACK_ENCRYPTION_KEY = "fallback-encryption-key"
    APP_SECRET              = "app-secret"
    AWS_SECRET_ACCESS_KEY   = "storage-secret-access-key"
  }

  server_env = merge(local.base_env, {
    NODE_PORT  = "3000"
    SERVER_URL = "https://${var.domain}"
  })

  worker_env = merge(local.base_env, {
    SERVER_URL                     = "https://${var.domain}"
    DISABLE_DB_MIGRATIONS          = "true" # already runs on the server
    DISABLE_CRON_JOBS_REGISTRATION = "true" # already runs on the server
  })
}

resource "google_cloud_run_v2_service" "server" {
  name                = "twenty"
  project             = var.project_id
  location            = var.region
  deletion_protection = false
  ingress             = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = google_service_account.cloud_run.email

    scaling {
      min_instance_count = var.server_min_instance_count
      max_instance_count = var.server_max_instance_count
    }

    vpc_access {
      connector = module.network.vpc_connector_id
      egress    = "PRIVATE_RANGES_ONLY"
    }

    containers {
      name  = "server"
      image = local.image

      ports {
        container_port = 3000
      }

      resources {
        limits = {
          cpu    = var.server_cpu
          memory = var.server_memory
        }
      }

      dynamic "env" {
        for_each = local.server_env
        content {
          name  = env.key
          value = env.value
        }
      }

      dynamic "env" {
        for_each = local.secret_env
        content {
          name = env.key
          value_source {
            secret_key_ref {
              secret  = google_secret_manager_secret.twenty[env.value].secret_id
              version = "latest"
            }
          }
        }
      }

      startup_probe {
        http_get {
          path = "/healthz"
          port = 3000
        }
        initial_delay_seconds = 10
        period_seconds        = 5
        failure_threshold     = 20
        timeout_seconds       = 5
      }

      liveness_probe {
        http_get {
          path = "/healthz"
          port = 3000
        }
        period_seconds  = 10
        timeout_seconds = 5
      }
    }
  }

  depends_on = [
    module.postgresql,
    module.redis,
    google_secret_manager_secret_version.twenty,
  ]
}

resource "google_cloud_run_v2_worker_pool" "worker" {
  name                = "twenty-worker"
  project             = var.project_id
  location            = var.region
  deletion_protection = false

  template {
    service_account = google_service_account.cloud_run.email

    vpc_access {
      connector = module.network.vpc_connector_id
      egress    = "PRIVATE_RANGES_ONLY"
    }

    containers {
      name    = "worker"
      image   = local.image
      command = ["yarn", "worker:prod"]

      resources {
        limits = {
          cpu    = var.worker_cpu
          memory = var.worker_memory
        }
      }

      dynamic "env" {
        for_each = local.worker_env
        content {
          name  = env.key
          value = env.value
        }
      }

      dynamic "env" {
        for_each = local.secret_env
        content {
          name = env.key
          value_source {
            secret_key_ref {
              secret  = google_secret_manager_secret.twenty[env.value].secret_id
              version = "latest"
            }
          }
        }
      }
    }
  }

  scaling {
    scaling_mode          = "MANUAL"
    manual_instance_count = var.worker_instance_count
  }

  depends_on = [
    module.postgresql,
    module.redis,
    google_secret_manager_secret_version.twenty,
    google_cloud_run_v2_service.server, # server owns DB migrations; let it boot first
  ]
}
