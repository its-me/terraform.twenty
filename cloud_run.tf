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
  name                = "twenty-server"
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
    google_redis_instance.main,
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
    google_redis_instance.main,
    google_secret_manager_secret_version.twenty,
    google_cloud_run_v2_service.server, # server owns DB migrations; let it boot first
  ]
}

# --- Public HTTPS access on var.domain ---
# Cloud Run Domain Mappings don't support asia-south1 (or several other regions), so we
# front the server with a global external HTTPS load balancer + serverless NEG instead.

resource "google_compute_region_network_endpoint_group" "server" {
  name                  = "twenty-server-neg"
  project               = var.project_id
  region                = var.region
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = google_cloud_run_v2_service.server.name
  }
}

resource "google_compute_backend_service" "server" {
  name                  = "twenty-server-backend"
  project               = var.project_id
  protocol              = "HTTPS"
  load_balancing_scheme = "EXTERNAL_MANAGED"

  backend {
    group = google_compute_region_network_endpoint_group.server.id
  }
}

resource "google_compute_managed_ssl_certificate" "server" {
  name    = "twenty-server-cert"
  project = var.project_id

  managed {
    domains = [var.domain]
  }
}

resource "google_compute_url_map" "server" {
  name            = "twenty-server-url-map"
  project         = var.project_id
  default_service = google_compute_backend_service.server.id
}

resource "google_compute_target_https_proxy" "server" {
  name             = "twenty-server-https-proxy"
  project          = var.project_id
  url_map          = google_compute_url_map.server.id
  ssl_certificates = [google_compute_managed_ssl_certificate.server.id]
}

resource "google_compute_global_address" "server_lb_ip" {
  name    = "twenty-server-lb-ip"
  project = var.project_id
}

resource "google_compute_global_forwarding_rule" "server_https" {
  name                  = "twenty-server-https-fr"
  project               = var.project_id
  target                = google_compute_target_https_proxy.server.id
  port_range            = "443"
  ip_address            = google_compute_global_address.server_lb_ip.id
  load_balancing_scheme = "EXTERNAL_MANAGED"
}

resource "google_compute_url_map" "server_http_redirect" {
  name    = "twenty-server-http-redirect"
  project = var.project_id

  default_url_redirect {
    https_redirect = true
    strip_query    = false
  }
}

resource "google_compute_target_http_proxy" "server" {
  name    = "twenty-server-http-proxy"
  project = var.project_id
  url_map = google_compute_url_map.server_http_redirect.id
}

resource "google_compute_global_forwarding_rule" "server_http" {
  name                  = "twenty-server-http-fr"
  project               = var.project_id
  target                = google_compute_target_http_proxy.server.id
  port_range            = "80"
  ip_address            = google_compute_global_address.server_lb_ip.id
  load_balancing_scheme = "EXTERNAL_MANAGED"
}
