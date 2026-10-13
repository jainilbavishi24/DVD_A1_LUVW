#!/usr/bin/env bash
# Start a shell in IIC-OSIC-TOOLS with this repository mounted persistently.
set -euo pipefail

if ! command -v docker >/dev/null 2>&1; then
    echo 'Docker is required. Install Docker, start its service, then run this script again.' >&2
    exit 1
fi

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec docker run --rm -it \
    --user "$(id -u):$(id -g)" \
    --security-opt seccomp=unconfined \
    --volume "$project_dir:/foss/designs/mult4_2023102045" \
    --workdir /foss/designs/mult4_2023102045 \
    hpretl/iic-osic-tools:latest --skip "${@:-bash}"
