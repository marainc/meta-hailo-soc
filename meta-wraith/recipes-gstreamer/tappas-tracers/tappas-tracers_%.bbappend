# Vendor recipe rule: never edit meta-hailo-* files directly -- patch from here instead.
#
# Same root cause as libgsthailotools (separate recipe, separate fetch of the same
# upstream tree): see files/0001-meson-treat-hailo15-as-single-arch-libdir-like-imx8.patch.
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
SRC_URI += "file://0001-meson-treat-hailo15-as-single-arch-libdir-like-imx8.patch"
