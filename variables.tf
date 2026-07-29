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

variable "image_tag" {
  description = "Tag of the twentycrm/twenty image to deploy (matches TAG in docker-compose.yml)."
  type        = string
  default     = "latest"
}

variable "db_name" {
  description = "Postgres database name (matches PG_DATABASE_NAME / default 'default' in docker-compose.yml)."
  type        = string
  default     = "default"
}

variable "db_user" {
  description = "Postgres user (matches PG_DATABASE_USER in docker-compose.yml)."
  type        = string
  default     = "twenty"
}

variable "db_tier" {
  description = "Cloud SQL machine tier for the Postgres instance."
  type        = string
  default     = "db-custom-1-3840"
}

variable "db_availability_type" {
  description = "Cloud SQL availability type: ZONAL or REGIONAL (REGIONAL = HA, higher cost)."
  type        = string
  default     = "ZONAL"
}

variable "db_disk_size_gb" {
  description = "Cloud SQL disk size in GB."
  type        = number
  default     = 20
}

variable "redis_tier" {
  description = "Memorystore Redis service tier: BASIC (single node) or STANDARD_HA (replica + failover)."
  type        = string
  default     = "BASIC"
}

variable "redis_memory_size_gb" {
  description = "Memorystore Redis instance memory size in GB."
  type        = number
  default     = 1
}

variable "server_cpu" {
  description = "vCPUs allocated to the server Cloud Run container."
  type        = string
  default     = "1"
}

variable "server_memory" {
  description = "Memory allocated to the server Cloud Run container."
  type        = string
  default     = "1Gi"
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
  default     = "1"
}

variable "worker_memory" {
  description = "Memory allocated to the worker pool container."
  type        = string
  default     = "1Gi"
}

variable "worker_instance_count" {
  description = "Fixed number of worker pool instances (manual scaling, mirrors the single `worker` service in docker-compose.yml)."
  type        = number
  default     = 1
}

variable "storage_bucket_location" {
  description = "Location for the GCS bucket backing Twenty's file storage."
  type        = string
}

variable "labels" {
  description = "Labels applied to all resources that support them."
  type        = map(string)
  default = {
    app        = "twenty"
    managed-by = "terraform"
  }
}
