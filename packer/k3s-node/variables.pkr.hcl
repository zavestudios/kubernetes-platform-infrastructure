variable "user" {
  description = "User and group for file ownership"
  type        = string
  default     = ""
}

variable "ubuntu_version" {
  type        = string
  description = "Ubuntu version to use"
  default     = "24.04"
}

variable "ubuntu_cloud_image_url" {
  type        = string
  description = "URL for Ubuntu cloud image"
  default     = "https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img"
}

variable "ubuntu_cloud_image_checksum" {
  type        = string
  description = "Checksum for Ubuntu cloud image"
  default     = "file:https://cloud-images.ubuntu.com/releases/24.04/release/SHA256SUMS"
}

variable "disk_size" {
  type        = string
  description = "Disk size for VM image"
  default     = "80G"
}

variable "memory" {
  type        = string
  description = "Memory for Packer build VM"
  default     = "2048"
}

variable "cpus" {
  type        = string
  description = "CPUs for Packer build VM"
  default     = "2"
}

variable "headless" {
  type        = bool
  description = "Run without GUI"
  default     = true
}

variable "output_directory" {
  type        = string
  description = "Directory for build output"
  default     = "output-qemu"
}

variable "vm_name" {
  type        = string
  description = "Name for output image"
  default     = "k3s-node-ubuntu-24.04"
}

variable "libvirt_pool_path" {
  type        = string
  description = "Path to libvirt storage pool"
  default     = ""
}
