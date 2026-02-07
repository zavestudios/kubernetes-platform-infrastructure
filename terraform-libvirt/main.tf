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

# Base volume (built by Packer, imported into Terraform state)
#
# Bootstrap Process:
# 1. Build base image: cd packer/k3s-node && packer build .
# 2. Import to Terraform: terraform import libvirt_volume.base /full/path/to/k3s-node-ubuntu-24.04.qcow2
# 3. Run terraform apply
#
# The lifecycle block prevents Terraform from destroying the Packer-built base image
resource "libvirt_volume" "base" {
  name   = var.base_volume_name
  pool   = var.libvirt_pool
  format = "qcow2"

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [source]
  }
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

# Bastion Host
resource "libvirt_volume" "bastion" {
  name           = "k3s-bastion-01.qcow2"
  pool           = var.libvirt_pool
  base_volume_id = libvirt_volume.base.id
  # Size inherited from base volume (80GB) - must be >= base volume size
  format         = "qcow2"
}

resource "libvirt_cloudinit_disk" "bastion" {
  name      = "k3s-bastion-01-cloudinit.iso"
  pool      = var.libvirt_pool
  user_data = templatefile("${path.module}/cloud-init/bastion.yml.tpl", {
    hostname         = "k3s-bastion-01"
    ssh_public_key   = local.ssh_public_key
    k3s_version      = local.k3s_version
    control_plane_ip = "192.168.122.10"
  })
  meta_data = <<-EOT
    instance-id: k3s-bastion-01-${uuid()}
    local-hostname: k3s-bastion-01
  EOT
  network_config = <<-EOT
    version: 2
    ethernets:
      ens3:
        addresses:
          - 192.168.122.13/24
        routes:
          - to: default
            via: 192.168.122.1
        nameservers:
          addresses: [8.8.8.8, 1.1.1.1]
  EOT
}

resource "libvirt_domain" "bastion" {
  name   = "k3s-bastion-01"
  memory = var.bastion_memory
  vcpu   = var.bastion_vcpu

  cloudinit = libvirt_cloudinit_disk.bastion.id

  disk {
    volume_id = libvirt_volume.bastion.id
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
