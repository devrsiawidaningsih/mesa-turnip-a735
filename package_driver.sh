#!/usr/bin/env bash
# ============================================================================
# package_driver.sh — Wrap a built libvulkan_freedreno.so into the zip
#                     format that Suyu and Eden Nintendo Switch emulators
#                     load via their "custom Vulkan driver" menu.
#
# Package format (verified against Suyu 0.0.4+ and Eden 0.0.3+):
#   <root>/
#     libvulkan_freedreno.so        # the driver itself
#     meta.json                     # manifest with: name, driverVersion,
#                                   #                libraryName, author,
#                                   #                description, ...
#
# The zip must have the .so at the root (or inside one top-level folder).
# Both Suyu and Eden accept either layout; this script produces the flat
# root layout because it is what the emulators' install dialog shows
# in the file picker.
#
# Usage:
#   ./package_driver.sh \
#       --so path/to/libvulkan_freedreno.so \
#       --version 26.3.0-a735 \
#       --out  out/mesa-turnip-a735-suyu-eden-26.3.0.zip
#
#   Optional:
#     --name "Mesa Turnip A735"      (default "Mesa Turnip A735 (Suyu/Eden)")
#     --author "myself"
#     --description "..."
#     --meta-only                    (no .so in zip, manifest only — rare)
# ============================================================================
set -euo pipefail

NAME="Mesa Turnip A735 (Suyu/Eden)"
AUTHOR="mesa-turnip-a735-suyu-eden build scripts"
DESCRIPTION="Mesa Turnip (freedreno Vulkan) built for Adreno 735 on Snapdragon 8s Gen 3 (SM8635). All Vulkan extensions enabled for Android. KGSL backend. Use with Suyu or Eden Nintendo Switch emulators via the 'Load custom driver' menu."
VERSION=""
SO=""
OUT=""
META_ONLY=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --so)         SO="$2"; shift 2 ;;
        --version)    VERSION="$2"; shift 2 ;;
        --name)       NAME="$2"; shift 2 ;;
        --author)     AUTHOR="$2"; shift 2 ;;
        --description) DESCRIPTION="$2"; shift 2 ;;
        --out)        OUT="$2"; shift 2 ;;
        --meta-only)  META_ONLY=1; shift ;;
        -h|--help)
            sed -n '2,30p' "${BASH_SOURCE[0]}"
            exit 0 ;;
        *) echo "unknown arg: $1" >&2; exit 2 ;;
    esac
done

[[ -n "${VERSION}" ]] || { echo "package_driver: --version is required" >&2; exit 2; }
[[ -n "${OUT}"     ]] || { echo "package_driver: --out is required" >&2; exit 2; }
if [[ ${META_ONLY} -eq 0 ]]; then
    [[ -n "${SO}" && -f "${SO}" ]] || {
        echo "package_driver: --so <path> is required and must exist (or pass --meta-only)" >&2
        exit 2
    }
fi

# ---- working dir -----------------------------------------------------------
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

LIB_NAME="libvulkan_freedreno.so"

if [[ ${META_ONLY} -eq 0 ]]; then
    echo "package_driver: staging ${SO} -> ${WORK}/${LIB_NAME}"
    cp "${SO}" "${WORK}/${LIB_NAME}"

    # Sanity: ensure the .so is arm64 ELF and stripped if possible
    FILE_INFO="$(file "${WORK}/${LIB_NAME}")"
    case "${FILE_INFO}" in
        *"ELF 64-bit LSB"*"ARM aarch64"*)
            echo "package_driver: ELF arm64 verified" ;;
        *)
            echo "package_driver: WARNING — .so does not look like an ARM64 ELF:" >&2
            echo "  ${FILE_INFO}" >&2
            echo "  Continuing anyway, but the emulator may refuse to load it." >&2
            ;;
    esac
fi

# ---- write meta.json -------------------------------------------------------
# We hand-write the JSON to avoid a jq runtime dependency.
META="${WORK}/meta.json"
cat > "${META}" <<JSON
{
  "name": "${NAME//\"/\\\"}",
  "driverVersion": "${VERSION//\"/\\\"}",
  "libraryName": "${LIB_NAME}",
  "author": "${AUTHOR//\"/\\\"}",
  "description": "${DESCRIPTION//\"/\\\"}",
  "supportedGpus": [
    { "vendor": "qualcomm", "model": "Adreno 735", "deviceId": "0x43050a" }
  ],
  "minApiLevel": 26
}
JSON
echo "package_driver: wrote ${META}"

# Optional: also drop driver_package_metadata.json (Android 14+ VK loader
# spec) — Suyu/Eden ignore it but it doesn't hurt, and it lets the same
# zip work if a future Android loader wants the new manifest.
META2="${WORK}/driver_package_metadata.json"
cat > "${META2}" <<JSON
{
  "schema_version": 1,
  "name": "${NAME//\"/\\\"}",
  "version": {
    "major": $(echo "${VERSION}" | awk -F. '{print $1}'),
    "minor": $(echo "${VERSION}" | awk -F. '{print $2+0}'),
    "patch": $(echo "${VERSION}" | awk -F. '{print $3+0}')
  },
  "vendor": "Mesa / freedreno",
  "library_filename": "${LIB_NAME}",
  "library_version": "${VERSION//\"/\\\"}",
  "description": "${DESCRIPTION//\"/\\\"}",
  "supported_devices": [
    {
      "vendor": "qualcomm",
      "soc": "SM8635",
      "gpu": "Adreno 735",
      "chip_id": "0x43050a"
    }
  ],
  "android": {
    "min_api_level": 26,
    "target_api_level": 35,
    "abi": "arm64-v8a"
  },
  "icd": {
    "api_version": "1.3",
    "implementation_version": "1"
  }
}
JSON
echo "package_driver: wrote ${META2}"

# ---- zip -------------------------------------------------------------------
# Convert OUT to an absolute path so the subshell `cd "${WORK}"` below does
# not redirect the output into WORK (which gets rm-rf'd on exit).
case "${OUT}" in
    /*) : ;;                                  # already absolute
    *)  OUT="$(pwd)/${OUT}" ;;
esac
mkdir -p "$(dirname "${OUT}")"
( cd "${WORK}" && zip -9 -j "${OUT}" ./* )     # -j: junk paths (flat root)
echo "package_driver: wrote ${OUT}"
echo
echo "package_driver: contents:"
unzip -l "${OUT}"
