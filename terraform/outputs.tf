output "master_nodes_ips" {
  description = "Public IPs of master nodes"
  value       = { for name, instance in aws_instance.master_nodes : "master-${name}" => instance.public_ip }
}

output "master_nodes_private_ips" {
  description = "Private IPs of master nodes"
  value       = { for name, instance in aws_instance.master_nodes : "master-${name}" => instance.private_ip }
}

output "worker_nodes_ips" {
  description = "Public IPs of worker nodes"
  value       = { for name, instance in aws_instance.worker_nodes : "worker-${name}" => instance.public_ip }
}

output "worker_nodes_private_ips" {
  description = "Private IPs of worker nodes"
  value       = { for name, instance in aws_instance.worker_nodes : "worker-${name}" => instance.private_ip }
}

output "haproxy_node_ip" {
  description = "Public IP of HAProxy node (Ingress)"
  value       = aws_instance.haproxy_lb.public_ip
}
