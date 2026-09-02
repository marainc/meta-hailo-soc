#!/bin/sh
# Build the wraith image. Use this instead of calling kas-container directly.
#
# The kas container image version is PINNED and that pin is load-bearing:
# kas 5.3's image is Debian trixie (Python 3.13), and kirkstone-era bitbake
# dies partway through parsing under it ("parser thread killed/died?" after
# exceptions in unrelated meta-openembedded recipes — freerdp, usbmuxd,
# tvheadend). kas 4.7's image is Debian bookworm (Python 3.11) and parses all
# 2774 recipes with 0 errors. Verified by A/B: same script, same layers, only
# the image version changed.
#
# Do not build natively either — poky kirkstone's pseudo cannot intercept a
# modern host tar's *at() syscalls, so native builds fail in do_install.
#
# Usage:  ./kas/build-wraith.sh            # full build (hours)
#         ./kas/build-wraith.sh -c 'bitbake -p'   # anything else -> kas shell
set -eu

KAS_IMAGE_VERSION=4.7
export KAS_IMAGE_VERSION

cd "$(dirname "$0")/.."

# --memory caps the container so a parallel-heavy task can't OOM a 14 GB host.
# lowmem.yml already caps BB_NUMBER_THREADS/PARALLEL_MAKE to match.
RUNTIME_ARGS="--memory=12g"

if [ $# -eq 0 ]; then
	exec kas-container --runtime-args "$RUNTIME_ARGS" build kas/wraith.yml
else
	exec kas-container --runtime-args "$RUNTIME_ARGS" shell kas/wraith.yml "$@"
fi
