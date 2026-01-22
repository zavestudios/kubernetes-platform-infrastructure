#!/bin/bash
# keep-latest-backups.sh
# Run from scripts/ directory

cd "$(dirname "$0")/.."  # Go to terraform directory

# Keep only 2 most recent numbered backups
ls -t terraform.tfstate.*.backup 2>/dev/null | tail -n +3 | xargs rm -f

echo "Kept 2 most recent numbered backups"