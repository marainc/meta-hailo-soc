# Vendor recipe rule: never edit meta-hailo-* files directly -- patch from here instead.
#
# Same root cause as libgsthailotools (separate recipe, separate fetch of the same
# upstream tree): see files/0001-meson-treat-hailo15-as-single-arch-libdir-like-imx8.patch.
# This recipe already overrides -Dpost_processes_install_dir explicitly so it doesn't
# hard-fail without this patch, but its tracking subdir's do_install:append() cleanup
# (rm -rf ${D}/usr/lib/libhailo_tracker*) silently no-ops against the wrong path without
# it, leaving a stray duplicate under the Debian-multiarch path in the image.
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
SRC_URI += "file://0001-meson-treat-hailo15-as-single-arch-libdir-like-imx8.patch"
