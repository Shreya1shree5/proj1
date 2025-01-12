# Configure the Google Cloud provider
provider "google" {
  project = var.project_id
  region  = var.region
}

# Terraform configuration
terraform {
  required_version = ">= 0.12"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}

# GCS bucket for Terraform state (equivalent to S3)
resource "google_storage_bucket" "terraform_state" {
  name          = "gab-terraform-state-${terraform.workspace}"
  location      = var.region
  force_destroy = false
  
  versioning {
    enabled = true
  }
}

# VPC Network (equivalent to AWS VPC)
resource "google_compute_network" "main" {
  name                    = "vpc-${terraform.workspace}"
  auto_create_subnetworks = false
}

# Subnets (equivalent to AWS Subnets)
resource "google_compute_subnetwork" "main" {
  count         = 2
  name          = "subnet-${count.index}-${terraform.workspace}"
  ip_cidr_range = cidrsubnet(var.vpc_cidr_block, 8, count.index)
  network       = google_compute_network.main.id
  region        = var.region

  # Enable private Google access
  private_ip_google_access = true
}

# Cloud Router for NAT Gateway
resource "google_compute_router" "router" {
  name    = "router-${terraform.workspace}"
  network = google_compute_network.main.id
  region  = var.region
}

# Cloud NAT (equivalent to Internet Gateway)
resource "google_compute_router_nat" "nat" {
  name                               = "nat-${terraform.workspace}"
  router                            = google_compute_router.router.name
  region                            = var.region
  nat_ip_allocate_option            = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# GKE Cluster (equivalent to EKS)
resource "google_container_cluster" "primary" {
  name     = "gke-cluster-${terraform.workspace}"
  location = var.region

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.main.self_link
  subnetwork = google_compute_subnetwork.main[0].self_link

  # IP allocation policy for VPC-native cluster
  ip_allocation_policy {
    cluster_ipv4_cidr_block  = "/16"
    services_ipv4_cidr_block = "/22"
  }
}

# GKE Node Pool (equivalent to EKS Node Group)
resource "google_container_node_pool" "primary_nodes" {
  name       = "node-pool-${terraform.workspace}"
  location   = var.region
  cluster    = google_container_cluster.primary.name
  node_count = 1

  node_config {
    machine_type = "e2-medium"  # equivalent to t2.medium
    
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}

# Firewall Rules (equivalent to Security Groups)
resource "google_compute_firewall" "allow_internal" {
  name    = "allow-internal-${terraform.workspace}"
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = [var.vpc_cidr_block]
}

resource "google_compute_firewall" "allow_external" {
  name    = "allow-external-${terraform.workspace}"
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
}

# Artifact Registry (equivalent to ECR)
resource "google_artifact_registry_repository" "app_repo" {
  location      = var.region
  repository_id = "gabapprepo${terraform.workspace}"
  format        = "DOCKER"
}

# Compute Instance (equivalent to EC2)
resource "google_compute_instance" "ubuntu_instance" {
  name         = "gab-instance-${terraform.workspace}"
  machine_type = "e2-micro"  # equivalent to t2.micro
  zone         = "${var.region}-a"

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-lts"  # Ubuntu 20.04 LTS
    }
  }

  network_interface {
    network    = google_compute_network.main.self_link
    subnetwork = google_compute_subnetwork.main[0].self_link

    access_config {
      // Ephemeral public IP
    }
  }

  tags = ["gab-instance", terraform.workspace]
}