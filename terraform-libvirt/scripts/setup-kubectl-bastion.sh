#!/bin/bash
# setup-kubectl-bastion.sh
# Sets up kubectl access to k3s cluster via bastion host
#
# Usage: ./scripts/setup-kubectl-bastion.sh

set -e

KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/kpi.yaml}"
TUNNEL_PID_FILE="/tmp/k3s-bastion-tunnel.pid"

# Check if tunnel is already running
if [ -f "$TUNNEL_PID_FILE" ]; then
    PID=$(cat "$TUNNEL_PID_FILE")
    if ps -p "$PID" > /dev/null 2>&1; then
        echo "SSH tunnel already running (PID: $PID)"
        echo "To restart, first run: kill $PID && rm $TUNNEL_PID_FILE"
        exit 0
    else
        # Stale PID file
        rm -f "$TUNNEL_PID_FILE"
    fi
fi

echo "=== Setting up kubectl access via bastion host ==="
echo ""

# Check if kubeconfig exists
if [ ! -f "$KUBECONFIG_PATH" ]; then
    echo "Kubeconfig not found at $KUBECONFIG_PATH"
    echo ""
    echo "Retrieving kubeconfig from control plane..."
    mkdir -p "$(dirname "$KUBECONFIG_PATH")"

    # Fetch kubeconfig from control plane (via laptop's ProxyJump)
    ssh kpi-cp-01 'sudo cat /etc/rancher/k3s/k3s.yaml' > "$KUBECONFIG_PATH"

    # Update server to localhost (for tunnel)
    sed -i.bak 's/server: https:\/\/.*:6443/server: https:\/\/127.0.0.1:6443/g' "$KUBECONFIG_PATH"
    rm -f "${KUBECONFIG_PATH}.bak"

    echo "Kubeconfig saved to: $KUBECONFIG_PATH"
fi

# Ensure kubeconfig uses localhost
if grep -q "192.168.122.10" "$KUBECONFIG_PATH"; then
    echo "Updating kubeconfig to use localhost..."
    sed -i.bak 's/192.168.122.10/127.0.0.1/g' "$KUBECONFIG_PATH"
    rm -f "${KUBECONFIG_PATH}.bak"
fi

echo "Starting SSH tunnel through bastion..."
# SSH tunnel: laptop:6443 → bastion → control-plane:6443
ssh -f -N -L 6443:192.168.122.10:6443 kpi-bastion-01

# Find the tunnel PID
TUNNEL_PID=$(ps aux | grep '[s]sh -f -N -L 6443:192.168.122.10:6443' | awk '{print $2}')
if [ -n "$TUNNEL_PID" ]; then
    echo "$TUNNEL_PID" > "$TUNNEL_PID_FILE"
    echo "SSH tunnel established (PID: $TUNNEL_PID)"
else
    echo "Warning: Could not determine tunnel PID"
fi

echo ""
echo "=== Setup complete ==="
echo ""
echo "Export KUBECONFIG and test connection:"
echo "  export KUBECONFIG=$KUBECONFIG_PATH"
echo "  kubectl get nodes"
echo ""
echo "To stop the tunnel:"
echo "  kill $TUNNEL_PID"
echo "  rm $TUNNEL_PID_FILE"
echo ""
echo "Note: With --tls-san=127.0.0.1, TLS verification works correctly (no insecure-skip needed)"
echo ""
