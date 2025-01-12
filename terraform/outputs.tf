# GKE Cluster outputs
output "gke_cluster_name" {
  description = "The name of the GKE cluster"
  value       = google_container_cluster.primary.name
}

output "gke_cluster_endpoint" {
  description = "The endpoint for the GKE cluster"
  value       = google_container_cluster.primary.endpoint
}

# Compute Instance outputs
output "compute_instance_public_ip" {
  description = "The public IP of the Ubuntu compute instance"
  value       = google_compute_instance.ubuntu_instance.network_interface[0].access_config[0].nat_ip
}

output "compute_instance_private_ip" {
  description = "The private IP of the Ubuntu compute instance"
  value       = google_compute_instance.ubuntu_instance.network_interface[0].network_ip
}

# Network outputs
output "vpc_network_name" {
  description = "The name of the VPC network"
  value       = google_compute_network.main.name
}

output "vpc_network_id" {
  description = "The ID of the VPC network"
  value       = google_compute_network.main.id
}

# Subnet outputs
output "subnet_names" {
  description = "The names of the subnets"
  value       = google_compute_subnetwork.main[*].name
}

# Artifact Registry output
output "artifact_registry_repository" {
  description = "The name of the Artifact Registry repository"
  value       = google_artifact_registry_repository.app_repo.name
}