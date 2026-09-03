variable "project_id" {
  description = "GCP project ID to deploy Twenty CRM into."
  type        = string
}

variable "region" {
  description = "GCP region for all resources."
  type        = string
}

variable "domain" {
  description = "Custom domain Twenty will be served on (e.g. crm.example.com). Used for the Cloud Run domain mapping and SERVER_URL."
  type        = string
}

variable "network_name" {
  description = "Name prefix of the shared VPC network/subnet/connector (see terraform.module.network). Must match the value used by every other app sharing this VPC."
  type        = string
  default     = "tools"
}

variable "image_tag" {
  description = "Tag of the twentycrm/twenty image to deploy (matches TAG in docker-compose.yml)."
  type        = string
  default     = "latest"
}

variable "postgresql_instance_name" {
  description = "Name of the shared Cloud SQL instance (see terraform.module.postgresql). Must match the value used by every other app sharing this instance."
  type        = string
  default     = "postgresql0"
}

variable "postgresql_name" {
  description = "Postgres database name (matches PG_DATABASE_NAME / default 'default' in docker-compose.yml)."
  type        = string
  default     = "default"
}

variable "postgresql_user" {
  description = "Postgres user (matches PG_DATABASE_USER in docker-compose.yml)."
  type        = string
  default     = "twenty"
}

variable "redis_instance_name" {
  description = "Name of the shared Memorystore Redis instance (see terraform.module.redis). Must match the value used by every other app sharing this instance."
  type        = string
  default     = "redis0"
}

variable "redis_db" {
  description = "Redis logical DB index (0-15) this app uses to isolate its keys on the shared instance."
  type        = number
  default     = 0
}

variable "server_cpu" {
  description = "vCPUs allocated to the server Cloud Run container."
  type        = string
  default     = "0.5"
}

variable "server_memory" {
  description = "Memory allocated to the server Cloud Run container. Cloud Run requires at least 512Mi when cpu < 1."
  type        = string
  default     = "512Mi"
}

variable "server_min_instance_count" {
  description = "Minimum number of server instances. Kept at 1 so cron jobs registered on boot and websockets stay warm."
  type        = number
  default     = 1
}

variable "server_max_instance_count" {
  description = "Maximum number of server instances."
  type        = number
  default     = 3
}

variable "worker_cpu" {
  description = "vCPUs allocated to the worker pool container."
  type        = string
  default     = "0.5"
}

variable "worker_memory" {
  description = "Memory allocated to the worker pool container. Cloud Run requires at least 512Mi when cpu < 1."
  type        = string
  default     = "512Mi"
}

variable "worker_instance_count" {
  description = "Fixed number of worker pool instances (manual scaling, mirrors the single `worker` service in docker-compose.yml)."
  type        = number
  default     = 1
}

variable "storage_bucket_location" {
  description = "Location for the GCS bucket backing Twenty's file storage. Defaults to `region` if unset."
  type        = string
  default     = null
}

variable "labels" {
  description = "Labels applied to all resources that support them."
  type        = map(string)
  default = {
    app        = "twenty"
    managed-by = "terraform"
  }
}
