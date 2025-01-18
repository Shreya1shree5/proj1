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

# VPC Network
resource "google_compute_network" "main" {
  name                    = "vpc-one"
  auto_create_subnetworks = false
}

# Subnets
resource "google_compute_subnetwork" "main" {
  count         = 1  # Reduced to 1 subnet since we're using a single zone
  name          = "subnet-${count.index}-one"
  ip_cidr_range = cidrsubnet(var.vpc_cidr_block, 8, count.index)
  network       = google_compute_network.main.id
  region        = var.region

  private_ip_google_access = true
}

# Cloud Router for NAT Gateway
resource "google_compute_router" "router" {
  name    = "router-one"
  network = google_compute_network.main.id
  region  = var.region
}

# Cloud NAT
resource "google_compute_router_nat" "nat" {
  name                               = "nat-one"
  router                            = google_compute_router.router.name
  region                            = var.region
  nat_ip_allocate_option            = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# Firewall Rules
resource "google_compute_firewall" "allow_internal" {
  name    = "allow-internal-one"
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
  name    = "allow-external-one"
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
}

# Artifact Registry
resource "google_artifact_registry_repository" "app_repo" {
  location      = var.region
  repository_id = "gabapprepoone"
  format        = "DOCKER"
}

# Compute Instance
resource "google_compute_instance" "ubuntu_instance" {
  name         = "gab-instance-one"
  machine_type = "e2-micro"  # Free tier eligible
  zone         = var.zone    # Using specific zone instead of region

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-lts"
      size  = var.disk_size_gb
      type  = var.disk_type
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

  lifecycle {
    prevent_destroy = false
  }
}

# GKE Cluster - Zonal
resource "google_container_cluster" "primary" {
  name     = "gke-cluster-one"
  location = var.zone  # Changed to zone for zonal cluster

  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.main.self_link
  subnetwork = google_compute_subnetwork.main[0].self_link

  ip_allocation_policy {
    cluster_ipv4_cidr_block  = "/16"
    services_ipv4_cidr_block = "/22"
  }

  min_master_version = "latest"

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "0.0.0.0/0"
      display_name = "All"
    }
  }
}

# GKE Node Pool - Zonal
resource "google_container_node_pool" "primary_nodes" {
  name       = "node-pool-one"
  location   = var.zone
  cluster    = google_container_cluster.primary.name
  node_count = var.gke_num_nodes

  node_config {
    machine_type = var.machine_type

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    labels = {
      env = terraform.workspace
    }

    tags = ["gke-node", "${var.project_id}-gke"]
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}
