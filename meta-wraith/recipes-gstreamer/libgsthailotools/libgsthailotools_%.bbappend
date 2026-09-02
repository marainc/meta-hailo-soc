# Vendor recipe rule: never edit meta-hailo-* files directly -- patch from here instead.
#
# See files/0001-meson-treat-hailo15-as-single-arch-libdir-like-imx8.patch for the full
# rationale: the vendor meson.build hardcodes a Debian-multiarch install path unless
# target_platform == 'imx8', which hailo15 doesn't match, breaking the vendor recipe's
# own do_install:append() (mv: cannot stat '.../usr/lib/gstreamer-1.0/...': No such file
# or directory).
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
SRC_URI += "file://0001-meson-treat-hailo15-as-single-arch-libdir-like-imx8.patch"
