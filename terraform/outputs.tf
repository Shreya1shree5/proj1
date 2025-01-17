# GKE Cluster outputs
output "gke_cluster_name" {
  description = "The name of the GKE cluster"
  value       = google_container_cluster.primary.name
}

output "gke_cluster_endpoint" {
  description = "The endpoint for the GKE cluster"
  value       = google_container_cluster.primary.endpoint
}

output "gke_cluster_zone" {
  description = "The zone of the GKE cluster"
  value       = google_container_cluster.primary.location
}

output "gke_cluster_master_version" {
  description = "The master version of the GKE cluster"
  value       = google_container_cluster.primary.master_version
}

# Node Pool outputs
output "gke_node_pool_name" {
  description = "The name of the GKE node pool"
  value       = google_container_node_pool.primary_nodes.name
}

output "gke_node_pool_instance_group_urls" {
  description = "The instance group URLs of the GKE node pool"
  value       = google_container_node_pool.primary_nodes.instance_group_urls
}
