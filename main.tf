terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.45.2"
    }
  }
  required_version = ">= 1.5.0"
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# -------------------------------------------------
# Enable Secret Manager API (safe, idempotent)
# -------------------------------------------------
resource "google_project_service" "secret_manager_api" {
  project             = var.project_id
  service             = "secretmanager.googleapis.com"
  disable_on_destroy  = false
}

# -------------------------------------------------
# Secret Manager (for DB password)
# -------------------------------------------------
resource "google_secret_manager_secret" "db_password" {
  depends_on = [google_project_service.secret_manager_api]
  project    = var.project_id
  secret_id  = "shopware-db-password"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_password_version" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = var.db_password
}

# -------------------------------------------------
# Networking
# -------------------------------------------------
resource "google_compute_network" "shopware_network" {
  name                    = "shopware-network"
  auto_create_subnetworks = true
}

# -------------------------------------------------
# Firewall
# -------------------------------------------------
resource "google_compute_firewall" "shopware_firewall" {
  name    = "shopware-firewall"
  network = google_compute_network.shopware_network.name

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
}

# -------------------------------------------------
# Static IP
# -------------------------------------------------
resource "google_compute_address" "shopware_ip" {
  name   = "shopware-ip"
  region = var.region
}

# -------------------------------------------------
# Service Account (for VM)
# -------------------------------------------------
resource "google_service_account" "shopware_sa" {
  account_id   = "shopware-vm-sa"
  display_name = "Shopware VM Service Account"
}

# Allow the VM to access Secret Manager
resource "google_project_iam_member" "shopware_secret_access" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.shopware_sa.email}"
}

# -------------------------------------------------
# Compute Instance (Shopware VM)
# -------------------------------------------------
resource "google_compute_instance" "shopware_vm" {
  name         = "shopware-demo"
  machine_type = "e2-medium"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 30
    }
  }

  network_interface {
    network = google_compute_network.shopware_network.name
    access_config {
      nat_ip = google_compute_address.shopware_ip.address
    }
  }

  service_account {
    email  = google_service_account.shopware_sa.email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  metadata = {
    enable-oslogin     = "TRUE"
    serial-port-enable = "TRUE"
  }

  metadata_startup_script = file("install_shopware.sh")

  tags = ["shopware"]
}

# -------------------------------------------------
# Output
# -------------------------------------------------
output "shopware_ip" {
  value       = google_compute_address.shopware_ip.address
  description = "External IP address of the Shopware VM"
}
