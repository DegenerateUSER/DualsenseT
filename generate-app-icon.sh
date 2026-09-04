#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SOURCE="${ROOT}/Assets/Brand/AppIcon-3A.svg"
OUTPUT="${ROOT}/Assets/AppIcon.icns"
WORK_DIR="$(mktemp -d)"
ICONSET="${WORK_DIR}/StickyFingers.iconset"
MASTER="${WORK_DIR}/icon-1024.png"

trap 'rm -rf "${WORK_DIR}"' EXIT

if [ ! -f "${SOURCE}" ]; then
    echo "Missing icon source: ${SOURCE}"
    exit 1
fi

mkdir -p "${ICONSET}"
sips -s format png "${SOURCE}" --out "${MASTER}" >/dev/null

render() {
    local pixels="$1"
    local destination="$2"
    sips -z "${pixels}" "${pixels}" "${MASTER}" \
        --out "${ICONSET}/${destination}" >/dev/null
}

render 16 icon_16x16.png
render 32 icon_16x16@2x.png
render 32 icon_32x32.png
render 64 icon_32x32@2x.png
render 128 icon_128x128.png
render 256 icon_128x128@2x.png
render 256 icon_256x256.png
render 512 icon_256x256@2x.png
render 512 icon_512x512.png
cp "${MASTER}" "${ICONSET}/icon_512x512@2x.png"

iconutil -c icns "${ICONSET}" -o "${OUTPUT}"
echo "Generated ${OUTPUT} from Assets/Brand/AppIcon-3A.svg"

