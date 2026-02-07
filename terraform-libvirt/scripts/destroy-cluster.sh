#!/bin/bash
# destroy-cluster.sh
# Safely destroys k3s cluster VMs while preserving the Packer-built base volume
#
# Usage: ./scripts/destroy-cluster.sh

set -e

cd "$(dirname "$0")/.."

echo "=== Destroying k3s cluster (preserving base volume) ==="
echo ""
echo "This will destroy:"
echo "  - Control plane, worker, and bastion VMs"
echo "  - VM volumes (qcow2 files)"
echo "  - Cloud-init ISOs"
echo ""
echo "This will PRESERVE:"
echo "  - Base volume (k3s-node-ubuntu-24.04.qcow2)"
echo ""

read -p "Continue? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo "Destroying cluster resources..."
docker compose run --rm terraform destroy \
  -target=libvirt_domain.control_plane \
  -target=libvirt_domain.worker \
  -target=libvirt_domain.bastion \
  -target=libvirt_volume.control_plane \
  -target=libvirt_volume.worker \
  -target=libvirt_volume.bastion \
  -target=libvirt_cloudinit_disk.control_plane \
  -target=libvirt_cloudinit_disk.worker \
  -target=libvirt_cloudinit_disk.bastion

echo ""
echo "=== Cluster destroyed successfully ==="
echo ""
echo "Base volume preserved at: /home/xlopez/libvirt_images/k3s-node-ubuntu-24.04.qcow2"
echo ""
echo "To recreate cluster:"
echo "  docker compose run --rm terraform apply"
