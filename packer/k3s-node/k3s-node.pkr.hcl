packer {
  required_version = ">= 1.9.0"
  
  required_plugins {
    qemu = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

source "qemu" "ubuntu" {
  # Use Ubuntu Cloud Image instead of ISO
  iso_url      = var.ubuntu_cloud_image_url
  iso_checksum = var.ubuntu_cloud_image_checksum
  
  # VM Settings
  vm_name       = var.vm_name
  disk_size     = var.disk_size
  disk_image    = true  # Important: tells Packer this is a disk image, not ISO
  format        = "qcow2"
  accelerator   = "kvm"
  memory        = var.memory
  cpus          = var.cpus
  headless      = var.headless
  
  # Network
  net_device = "virtio-net"
  disk_interface = "virtio"
  
  # Output
  output_directory = var.output_directory
  
  # Create cloud-init seed ISO
  cd_content = {
    "meta-data" = file("cloud-init/meta-data")
    "user-data" = file("cloud-init/user-data")
  }
  cd_label = "cidata"
  
  # SSH Configuration
  ssh_username         = "ubuntu"
  ssh_password         = "ubuntu"
  ssh_timeout          = "10m"
  ssh_handshake_attempts = 100
  
  # Shutdown
  shutdown_command = "echo 'ubuntu' | sudo -S shutdown -P now"
}

build {
  name = "k3s-node"
  
  sources = ["source.qemu.ubuntu"]
  
  # Wait for cloud-init to complete
  provisioner "shell" {
    inline = [
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 1; done",
      "echo 'Cloud-init complete'"
    ]
  }
  
  # System updates and base packages
  provisioner "shell" {
    script = "scripts/setup.sh"
  }
  
  # Clean up before image creation
  provisioner "shell" {
    inline = [
      "sudo apt-get clean",
      "sudo cloud-init clean --logs --seed",
      "sudo rm -rf /var/lib/cloud/instances/*",
      "sudo rm -rf /var/log/cloud-init*",
      "sudo sync"
    ]
  }
  
  # Copy image to libvirt pool
  post-processor "shell-local" {
    inline = [
      "echo 'Copying image to libvirt pool...'",
      "mkdir -p ${var.libvirt_pool_path}/libvirt_images",
      "cp ${var.output_directory}/${var.vm_name} ${var.libvirt_pool_path}/libvirt_images/${var.vm_name}.qcow2",
      "echo 'Image available at: ${var.libvirt_pool_path}/libvirt_images/${var.vm_name}.qcow2'"
    ]
  }
}
