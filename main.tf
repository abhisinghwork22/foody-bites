terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}

provider "google" {
  region = "us-central1"
}

# 1. Enable required GCP APIs declaratively
resource "google_project_service" "apis" {
  for_each = toset([
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com"
  ])
  
  service            = each.key
  disable_on_destroy = false
}

# 2. Force a 30-second delay for API permission propagation
resource "time_sleep" "wait_for_apis" {
  depends_on      = [google_project_service.apis]
  create_duration = "30s"
}

# 3. Create Google Artifact Registry repository for Docker images
resource "google_artifact_registry_repository" "foody_repo" {
  location      = "us-central1"
  repository_id = "foody-repo"
  description   = "Foody Bites Docker repository managed by Terraform"
  format        = "DOCKER"
  depends_on    = [time_sleep.wait_for_apis]
}