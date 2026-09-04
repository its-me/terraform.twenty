resource "google_service_account" "cloud_run" {
  project      = var.project_id
  account_id   = "twenty-cloud-run"
  display_name = "Twenty CRM Cloud Run (server + worker)"
}

resource "google_project_iam_member" "cloud_run_cloudsql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.cloud_run.email}"
}

resource "google_secret_manager_secret_iam_member" "cloud_run_secret_access" {
  for_each = google_secret_manager_secret.twenty

  project   = var.project_id
  secret_id = each.value.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.cloud_run.email}"
}

# Required for the load balancer's serverless NEG to reach this service. Without it,
# GCP's front end rejects every request before it reaches Cloud Run at all (a generic
# "Error: Forbidden" page from "Google Frontend", not an app-level error).
resource "google_cloud_run_v2_service_iam_member" "server_public" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.server.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
