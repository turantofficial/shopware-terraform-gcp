variable "project_id" {
  description = "Google Cloud project ID"
  type        = string
}

variable "region" {
  description = "Default GCP region"
  type        = string
  default     = "europe-west3"
}

variable "zone" {
  description = "Default GCP zone"
  type        = string
  default     = "europe-west3-c"
}

variable "db_password" {
  description = "Database password stored securely in Secret Manager"
  type        = string
  sensitive   = true
}
