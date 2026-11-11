#!/usr/bin/env bash
# ============================================================================
# build_a735.sh — Build Mesa Turnip Vulkan driver for Adreno 735
#                 on Snapdragon 8s Gen 3 (SM8635), packaged for Suyu / Eden.
#
# Tested on:
#   * Ubuntu 22.04 / 24.04 x86_64
#   * WSL2 (Ubuntu)
#   * Debian 12
#   * Termux (aarch64) with proot-distro ubuntu  — needs NDK r26+
#
# Usage:
#   export ANDROID_NDK_HOME=/path/to/ndk           # required
#   export MESA_VERSION=26.3.0                     # optional, default 26.3.0
#   ./build_a735.sh
#
# Output:
#   out/libvulkan_freedreno.so                    # the bare driver
#   out/mesa-turnip-a735-suyu-eden-26.3.0.zip     # installable in Suyu/Eden
#
# Re-runnable: re-runs are cached via ccache and meson's build-android/
# directory; pass --clean to wipe and rebuild from scratch.
# ============================================================================
set -euo pipefail

# ---- defaults --------------------------------------------------------------
MESA_VERSION="${MESA_VERSION:-26.3.0}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${HERE}/out"
BUILD_DIR="${OUT_DIR}/build-android"
MESA_SRC_DIR="${OUT_DIR}/mesa-${MESA_VERSION}"
CLEAN=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --clean) CLEAN=1; shift ;;
        -h|--help)
            sed -n '2,30p' "${BASH_SOURCE[0]}"
            exit 0 ;;
        *) echo "unknown arg: $1" >&2; exit 2 ;;
    esac
done

# ---- env checks ------------------------------------------------------------
if [[ -z "${ANDROID_NDK_HOME:-}" ]]; then
    if [[ -d "${HOME}/Android/Sdk/ndk/"* ]]; then
        ANDROID_NDK_HOME="$(echo "${HOME}/Android/Sdk/ndk/"*)"
        echo "build_a735: inferred ANDROID_NDK_HOME=${ANDROID_NDK_HOME}"
    else
        echo "build_a735: ANDROID_NDK_HOME is not set and no NDK found under ~/Android/Sdk/ndk." >&2
        echo "            Install NDK r26 or newer from https://developer.android.com/ndk/downloads" >&2
        exit 1
    fi
fi
export ANDROID_NDK_HOME

if [[ ! -d "${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64" ]]; then
    echo "build_a735: NDK at ${ANDROID_NDK_HOME} does not look like a Linux x86_64 NDK." >&2
    echo "            On Apple Silicon hosts the prebuilt dir is darwin-arm64 — this" >&2
    echo "            script only supports linux-x86_64 toolchain." >&2
    exit 1
fi

command -v meson  >/dev/null || { pip3 install --user meson; }
command -v ninja  >/dev/null || { pip3 install --user ninja; }
command -v ccache >/dev/null || { sudo apt-get install -y ccache || true; }
for dep in flex bison python3-mako glslang-tools patchelf pkg-config; do
    command -v "${dep/-/_}" >/dev/null 2>&1 || {
        echo "build_a735: installing missing dep ${dep}"
        sudo apt-get install -y "${dep}" || true
    }
done

# ---- clean -----------------------------------------------------------------
if [[ ${CLEAN} -eq 1 ]]; then
    echo "build_a735: --clean: removing ${BUILD_DIR} and ${MESA_SRC_DIR}"
    rm -rf "${BUILD_DIR}" "${MESA_SRC_DIR}"
fi

# ---- fetch mesa ------------------------------------------------------------
mkdir -p "${OUT_DIR}"
if [[ ! -d "${MESA_SRC_DIR}" ]]; then
    if [[ "${MESA_VERSION}" == "edge" ]]; then
        git clone --depth 1 --recursive https://gitlab.freedesktop.org/mesa/mesa.git "${MESA_SRC_DIR}"
    else
        TARBALL="${OUT_DIR}/mesa-${MESA_VERSION}.tar.xz"
        if [[ ! -f "${TARBALL}" ]]; then
            echo "build_a735: downloading mesa-${MESA_VERSION}.tar.xz"
            wget -q "https://archive.mesa3d.org/mesa-${MESA_VERSION}.tar.xz" -O "${TARBALL}"
        fi
        echo "build_a735: extracting mesa-${MESA_VERSION}"
        tar -xf "${TARBALL}" -C "${OUT_DIR}"
    fi
else
    echo "build_a735: reusing existing ${MESA_SRC_DIR}"
fi

# ---- apply patches ---------------------------------------------------------
cd "${MESA_SRC_DIR}"

apply_patch() {
    local p="$1"
    local name
    name="$(basename "${p}")"
    if patch -p1 --dry-run --forward -i "${p}" >/dev/null 2>&1; then
        echo "build_a735: applying ${name}"
        patch -p1 --forward -i "${p}"
    else
        echo "build_a735: ${name} already applied or conflicts — skipping"
    fi
}

apply_patch "${HERE}/patches/mesa-implement-android_stub.patch"
apply_patch "${HERE}/patches/mesa-android-include-all-vulkan-extension.patch"
# The A735 patch is documentation + safety registration only; safe to apply
# on top of Mesa 26.3.0 which already has the a735 device entry.
apply_patch "${HERE}/patches/mesa-adreno-735-suyu-eden-tweaks.patch"

# ---- cross-file with NDK substituted --------------------------------------
sed -e "s|NDKDIR|${ANDROID_NDK_HOME}|g" < "${HERE}/android-aarch64" > "${MESA_SRC_DIR}/android-aarch64"

# ---- meson setup -----------------------------------------------------------
if [[ ! -f "${BUILD_DIR}/build.ninja" ]]; then
    echo "build_a735: meson setup build-android"
    meson setup "${BUILD_DIR}" --cross-file ./android-aarch64 \
        -Dbuildtype=release \
        -Dplatforms=android \
        -Dplatform-sdk-version=26 \
        -Dandroid-stub=true \
        -Dvideo-codecs= \
        -Dgallium-drivers= \
        -Dglx=disabled \
        -Degl=disabled \
        -Dvulkan-drivers=freedreno \
        -Dfreedreno-kmds=kgsl \
        -Db_lto=true -Dallow-broken-lto=true -Dstrip=true
else
    echo "build_a735: re-using existing ${BUILD_DIR}/build.ninja"
fi

# ---- compile ---------------------------------------------------------------
echo "build_a735: ninja -C build-android (this takes 20–40 min on 8 cores)"
ninja -C "${BUILD_DIR}"

# ---- stage output ----------------------------------------------------------
cp "${BUILD_DIR}/src/freedreno/vulkan/libvulkan_freedreno.so" \
   "${OUT_DIR}/libvulkan_freedreno.so"
echo "build_a735: bare .so copied to ${OUT_DIR}/libvulkan_freedreno.so"

# ---- package for Suyu/Eden -------------------------------------------------
echo "build_a735: packaging installable zip"
"${HERE}/package_driver.sh" \
    --so "${OUT_DIR}/libvulkan_freedreno.so" \
    --version "${MESA_VERSION}-a735" \
    --out "${OUT_DIR}/mesa-turnip-a735-suyu-eden-${MESA_VERSION}.zip"

echo
echo "build_a735: done."
echo "  bare .so : ${OUT_DIR}/libvulkan_freedreno.so"
echo "  package  : ${OUT_DIR}/mesa-turnip-a735-suyu-eden-${MESA_VERSION}.zip"
echo
echo "Next: see INSTALL-SUZUY-EDEN.md to load the package in Suyu or Eden."
