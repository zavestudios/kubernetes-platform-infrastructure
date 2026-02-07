variable "ssh_public_key_path" {
  description = "Path to SSH public key for VM access"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "libvirt_uri" {
  description = "Libvirt connection URI"
  type        = string
  default     = "qemu:///system"
}

variable "libvirt_network" {
  description = "Name of libvirt network to use"
  type        = string
  default     = "host-bridge"
}

variable "libvirt_pool" {
  description = "Name of libvirt storage pool"
  type        = string
  default     = "libvirt_images"
}

variable "base_volume_name" {
  description = "Name of base volume in libvirt pool"
  type        = string
  default     = "k3s-node-ubuntu-24.04.qcow2"
}

variable "control_plane_count" {
  description = "Number of control plane nodes"
  type        = number
  default     = 1
}

variable "worker_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 2
}

variable "control_plane_vcpu" {
  description = "Number of vCPUs for control plane nodes"
  type        = number
  default     = 6
}

variable "control_plane_memory" {
  description = "Memory in MB for control plane nodes"
  type        = number
  default     = 10240
}

variable "worker_vcpu" {
  description = "Number of vCPUs for worker nodes"
  type        = number
  default     = 6
}

variable "worker_memory" {
  description = "Memory in MB for worker nodes"
  type        = number
  default     = 10240
}

variable "disk_size" {
  description = "Disk size in bytes (default 80GB)"
  type        = number
  default     = 85899345920
}

variable "k3s_version" {
  description = "k3s version to install (e.g., v1.31.1+k3s1). Leave empty for latest stable."
  type        = string
  default     = "v1.34.3+k3s1"
}

variable "k3s_token" {
  description = "Shared secret for k3s cluster. Auto-generated if not provided."
  type        = string
  default     = ""
  sensitive   = true
}

variable "bastion_vcpu" {
  description = "Number of vCPUs for bastion host"
  type        = number
  default     = 2
}

variable "bastion_memory" {
  description = "Memory in MB for bastion host"
  type        = number
  default     = 4096
}
