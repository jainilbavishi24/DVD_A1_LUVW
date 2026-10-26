#!/usr/bin/env bash
# Start a shell in IIC-OSIC-TOOLS with this repository mounted persistently.
# Pass a command to run it instead of a shell, e.g. ./run-osic.sh ./run_full_flow.sh
set -euo pipefail

# All committed results were produced with this exact image. The tag alone is
# not enough: "latest" moves and newer/older builds give different cell counts
# and timing, so the digest is pinned. Set OSIC_IMAGE to try another image.
image="${OSIC_IMAGE:-hpretl/iic-osic-tools:2026.10@sha256:306585de35d198e70ea58950f77147c86f56c698726a19afea9f1c83009557be}"

if ! command -v docker >/dev/null 2>&1; then
    echo 'Docker is required. Install Docker, start its service, then run this script again.' >&2
    exit 1
fi

tty_flags=(-i)
if [[ -t 0 && -t 1 ]]; then
    tty_flags+=(-t)
fi

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec docker run --rm "${tty_flags[@]}" \
    --user "$(id -u):$(id -g)" \
    --security-opt seccomp=unconfined \
    --volume "$project_dir:/foss/designs/mult4_2023102045" \
    --workdir /foss/designs/mult4_2023102045 \
    "$image" --skip "${@:-bash}"
