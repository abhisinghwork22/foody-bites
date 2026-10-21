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

# ==========================================
# VARIABLES (Update the defaults below!)
# ==========================================
variable "domain_name" {
  description = "Your custom domain name (without www)"
  type        = string
  default     = "foodybites.net" # <--- CHANGE THIS to your actual domain
}

variable "dns_zone_name" {
  description = "The Zone Name in Cloud DNS (not the domain name)"
  type        = string
  default     = "foodybites-net" # <--- CHANGE THIS to your Cloud DNS Zone Name
}

# Automatically fetch your current GCP Project ID
data "google_project" "current" {}

# 1. Enable required GCP APIs declaratively (Added dns.googleapis.com)
resource "google_project_service" "apis" {
  for_each = toset([
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "dns.googleapis.com"
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

  cleanup_policies {
    id     = "keep-minimum-versions"
    action = "KEEP"
    most_recent_versions {
      keep_count = 5
    }
  }
}

# ==========================================
# 4. CUSTOM DOMAIN & CLOUD DNS CONFIGURATION
# ==========================================

# Look up the existing Cloud DNS Zone created when you bought the domain
data "google_dns_managed_zone" "domain_zone" {
  name       = var.dns_zone_name
  depends_on = [time_sleep.wait_for_apis]
}

# Map Root Domain (e.g., foodybites.com) to Cloud Run Service
resource "google_cloud_run_domain_mapping" "root_domain" {
  location = "us-central1"
  name     = var.domain_name

  metadata {
    namespace = data.google_project.current.project_id
  }

  spec {
    route_name = "foody-bites-service"
  }

  depends_on = [time_sleep.wait_for_apis]
}

# Map WWW Subdomain (e.g., www.foodybites.com) to Cloud Run Service
resource "google_cloud_run_domain_mapping" "www_domain" {
  location = "us-central1"
  name     = "www.${var.domain_name}"

  metadata {
    namespace = data.google_project.current.project_id
  }

  spec {
    route_name = "foody-bites-service"
  }

  depends_on = [time_sleep.wait_for_apis]
}

# Create IPv4 'A' Records pointing root domain to Google Cloud Run IPs
resource "google_dns_record_set" "root_a" {
  name         = "${var.domain_name}." # Trailing dot is mandatory in DNS!
  managed_zone = data.google_dns_managed_zone.domain_zone.name
  type         = "A"
  ttl          = 300

  rrdatas = [
    "216.239.32.21",
    "216.239.34.21",
    "216.239.36.21",
    "216.239.38.21"
  ]
}

# Create IPv6 'AAAA' Records pointing root domain to Google Cloud Run IPs
resource "google_dns_record_set" "root_aaaa" {
  name         = "${var.domain_name}."
  managed_zone = data.google_dns_managed_zone.domain_zone.name
  type         = "AAAA"
  ttl          = 300

  rrdatas = [
    "2001:4860:4802:32::15",
    "2001:4860:4802:34::15",
    "2001:4860:4802:36::15",
    "2001:4860:4802:38::15"
  ]
}

# Create 'CNAME' Record pointing www subdomain to Google Hosted Services
resource "google_dns_record_set" "www_cname" {
  name         = "www.${var.domain_name}."
  managed_zone = data.google_dns_managed_zone.domain_zone.name
  type         = "CNAME"
  ttl          = 300

  rrdatas = ["ghs.googlehosted.com."]
}