locals {
  ssh_public_key = file(pathexpand(var.ssh_public_key_path))
  k3s_token      = var.k3s_token != "" ? var.k3s_token : random_password.k3s_token.result
  k3s_version    = var.k3s_version
}

# Generate random token for k3s cluster if not provided
resource "random_password" "k3s_token" {
  length  = 32
  special = false
}

# Base volume (used as backing image for all VMs)
resource "libvirt_volume" "base" {
  name   = var.base_volume_name
  pool   = var.libvirt_pool
  format = "qcow2"
}

# Control Plane Nodes
resource "libvirt_volume" "control_plane" {
  count          = var.control_plane_count
  name           = "k3s-cp-${format("%02d", count.index + 1)}.qcow2"
  pool           = var.libvirt_pool
  base_volume_id = libvirt_volume.base.id
  size           = var.disk_size
  format         = "qcow2"
}

resource "libvirt_cloudinit_disk" "control_plane" {
  count     = var.control_plane_count
  name      = "k3s-cp-${format("%02d", count.index + 1)}-cloudinit.iso"
  pool      = var.libvirt_pool
  user_data = templatefile("${path.module}/cloud-init/k3s-cp.yml.tpl", {
    hostname       = "k3s-cp-${format("%02d", count.index + 1)}"
    ssh_public_key = local.ssh_public_key
    k3s_version    = local.k3s_version
    k3s_token      = local.k3s_token
    node_index     = count.index
  })
  meta_data = <<-EOT
    instance-id: k3s-cp-${format("%02d", count.index + 1)}-${uuid()}
    local-hostname: k3s-cp-${format("%02d", count.index + 1)}
  EOT
  network_config = <<-EOT
    version: 2
    ethernets:
      ens3:
        addresses:
          - 192.168.122.10/24
        routes:
          - to: default
            via: 192.168.122.1
        nameservers:
          addresses: [8.8.8.8, 1.1.1.1]
  EOT
}

resource "libvirt_domain" "control_plane" {
  count  = var.control_plane_count
  name   = "k3s-cp-${format("%02d", count.index + 1)}"
  memory = var.control_plane_memory
  vcpu   = var.control_plane_vcpu

  cloudinit = libvirt_cloudinit_disk.control_plane[count.index].id

  disk {
    volume_id = libvirt_volume.control_plane[count.index].id
  }

  network_interface {
    network_name   = var.libvirt_network
    wait_for_lease = false
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }

  qemu_agent = false
}

# Worker Nodes
resource "libvirt_volume" "worker" {
  count          = var.worker_count
  name           = "k3s-worker-${format("%02d", count.index + 1)}.qcow2"
  pool           = var.libvirt_pool
  base_volume_id = libvirt_volume.base.id
  size           = var.disk_size
  format         = "qcow2"
}

resource "libvirt_cloudinit_disk" "worker" {
  count     = var.worker_count
  name      = "k3s-worker-${format("%02d", count.index + 1)}-cloudinit.iso"
  pool      = var.libvirt_pool
  user_data = templatefile("${path.module}/cloud-init/k3s-worker.yml.tpl", {
    hostname         = "k3s-worker-${format("%02d", count.index + 1)}"
    ssh_public_key   = local.ssh_public_key
    k3s_version      = local.k3s_version
    k3s_token        = local.k3s_token
    control_plane_ip = "192.168.122.10"  # Changed to static IP
  })
  meta_data = <<-EOT
    instance-id: k3s-worker-${format("%02d", count.index + 1)}-${uuid()}
    local-hostname: k3s-worker-${format("%02d", count.index + 1)}
  EOT
  network_config = <<-EOT
    version: 2
    ethernets:
      ens3:
        addresses:
          - 192.168.122.${11 + count.index}/24
        routes:
          - to: default
            via: 192.168.122.1
        nameservers:
          addresses: [8.8.8.8, 1.1.1.1]
  EOT
}

resource "libvirt_domain" "worker" {
  count  = var.worker_count
  name   = "k3s-worker-${format("%02d", count.index + 1)}"
  memory = var.worker_memory
  vcpu   = var.worker_vcpu

  cloudinit = libvirt_cloudinit_disk.worker[count.index].id

  disk {
    volume_id = libvirt_volume.worker[count.index].id
  }

  network_interface {
    network_name   = var.libvirt_network
    wait_for_lease = false
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }

  qemu_agent = false

  depends_on = [libvirt_domain.control_plane]
}
