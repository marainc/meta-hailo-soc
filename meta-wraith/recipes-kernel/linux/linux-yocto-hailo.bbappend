# wraith kernel config additions, as a fragment rather than an in-place edit of
# vendor's defconfig — so BSP bumps update vendor's defconfig cleanly and these
# re-apply on top.

FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI += "file://wraith-usb.cfg"
