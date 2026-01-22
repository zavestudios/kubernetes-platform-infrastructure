#!/bin/bash
# cleanup-libvirt-resources.sh
# Run this on zave-lab to clean up actual libvirt resources

set -e

echo "=== Cleaning up libvirt VMs and volumes ==="

# Destroy VMs
echo "Destroying VMs..."
for vm in k3s-cp-01 k3s-worker-01 k3s-worker-02; do
    if sudo virsh list --all | grep -q "$vm"; then
        echo "  Destroying $vm..."
        sudo virsh destroy "$vm" 2>/dev/null || true
        sudo virsh undefine "$vm" 2>/dev/null || true
    fi
done

# Delete volumes from libvirt pool
echo "Deleting volumes from libvirt pool..."
for vol in k3s-cp-01.qcow2 k3s-worker-01.qcow2 k3s-worker-02.qcow2 \
           k3s-cp-01-cloudinit.iso k3s-worker-01-cloudinit.iso k3s-worker-02-cloudinit.iso; do
    if sudo virsh vol-list --pool xlopez | grep -q "$vol"; then
        echo "  Deleting $vol from pool..."
        sudo virsh vol-delete --pool xlopez "$vol" 2>/dev/null || true
    fi
done

# Delete files directly from filesystem (catches anything libvirt doesn't know about)
echo "Cleaning up filesystem..."
cd /home/xlopez/libvirt_images
for file in k3s-cp-01.qcow2 k3s-worker-01.qcow2 k3s-worker-02.qcow2 \
            k3s-cp-01-cloudinit.iso k3s-worker-01-cloudinit.iso k3s-worker-02-cloudinit.iso; do
    if [ -f "$file" ]; then
        echo "  Removing $file..."
        sudo rm -f "$file"
    fi
done

echo "=== Libvirt cleanup complete ==="