provider "google" {
  project = "blissful-star-447402-i5"
  region  = "asia-southeast1"
}

# Create a Cloud Router
resource "google_compute_router" "nfs_router" {
  name    = "nfs-router"
  region  = "asia-southeast1"
  network = "default"
}

# Reserve static internal IP addresses for NFS servers
resource "google_compute_address" "nfs_ips" {
  count        = 3
  name         = "nfs-ip-${count.index + 1}"
  region       = "asia-southeast1"
  address_type = "INTERNAL"
  address      = "10.148.0.${100 + count.index}"
}

# Define zones for HA
locals {
  zones = ["asia-southeast1-a", "asia-southeast1-b", "asia-southeast1-c"]
}

# Configure Cloud NAT
resource "google_compute_router_nat" "nfs_nat" {
  name                               = "nfs-nat"
  router                             = google_compute_router.nfs_router.name
  region                             = google_compute_router.nfs_router.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# Create NFS instances
resource "google_compute_instance" "nfs_servers" {
  count        = 3
  name         = "storage-master-${count.index + 1}"
  machine_type = "e2-small"
  zone         = local.zones[count.index]

  boot_disk {
    initialize_params {
      image = "ubuntu-2410-oracular-amd64-v20250116"
    }
  }

  network_interface {
    network    = "default"
    subnetwork = "default"
    network_ip = google_compute_address.nfs_ips[count.index].address
  }

  tags = ["nfs-server"]
  metadata = {
    hostname = "storage-master-${count.index + 1}"
  }

  metadata_startup_script = <<-EOT
    #!/bin/bash
    # Install NFS and GlusterFS
    apt-get update
    apt-get install -y nfs-kernel-server glusterfs-server nfs-ganesha nfs-ganesha-gluster
    mkdir -p /data/nfs
    chown -R nobody:nogroup /data/nfs
    chmod 777 /data/nfs
    echo "/data/nfs *(rw,sync,no_subtree_check)" >> /etc/exports
    exportfs -a
    systemctl start nfs-kernel-server
    systemctl enable nfs-kernel-server
    systemctl start nfs-ganesha
    systemctl enable nfs-ganesha
  EOT
}

# Create instance group for each NFS node
resource "google_compute_instance_group" "nfs_group" {
  count     = 3
  name      = "nfs-group-${count.index + 1}"
  zone      = local.zones[count.index]
  instances = [google_compute_instance.nfs_servers[count.index].self_link]
}

# Health check for NFS (checks port 2049)
resource "google_compute_health_check" "nfs_health" {
  name               = "nfs-health"
  timeout_sec        = 5
  check_interval_sec = 10

  tcp_health_check {
    port = 2049
  }
}

# Backend service for the ILB
resource "google_compute_region_backend_service" "nfs_backend" {
  name                  = "nfs-backend"
  region                = "asia-southeast1"
  protocol              = "TCP"
  load_balancing_scheme = "INTERNAL"
  health_checks         = [google_compute_health_check.nfs_health.id]

  dynamic "backend" {
    for_each = google_compute_instance_group.nfs_group[*]
    content {
      group          = backend.value.id
      balancing_mode = "CONNECTION"
    }
  }
}

# Internal Load Balancer Forwarding Rule
resource "google_compute_forwarding_rule" "nfs_ilb" {
  name                  = "nfs-ilb"
  region                = "asia-southeast1"
  load_balancing_scheme = "INTERNAL"
  backend_service       = google_compute_region_backend_service.nfs_backend.id
  ip_protocol           = "TCP"
  ports                 = ["2049"]
  subnetwork            = "default"
}

# Output ILB IP
output "nfs_internal_lb_ip" {
  value = google_compute_forwarding_rule.nfs_ilb.ip_address
}
