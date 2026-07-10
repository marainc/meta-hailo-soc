SUMMARY = "v4l2loopback virtual video device kernel module"
DESCRIPTION = "Out-of-tree kernel module providing virtual V4L2 capture devices. \
Used to expose a network-forwarded camera (host thermal cam over RTP/UDP) as a \
local /dev/video node, since isochronous UVC cannot cross USB/IP."
HOMEPAGE = "https://github.com/umlaeute/v4l2loopback"
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://COPYING;md5=b234ee4d69f5fce4486a80fdaf4a4263"

inherit module

SRC_URI = "git://github.com/umlaeute/v4l2loopback.git;protocol=https;branch=main"
SRCREV = "2d44c2f3a33844dfd9928dc536288283289bbc34"
S = "${WORKDIR}/git"

EXTRA_OEMAKE += "KERNEL_DIR=${STAGING_KERNEL_BUILDDIR}"

# Build/install only the kernel module; the default 'all' target also builds
# the userspace v4l2loopback-ctl, which module.bbclass cannot compile.
MAKE_TARGETS = "v4l2loopback.ko"
MODULES_INSTALL_TARGET = "install"

# Autoload at boot as /dev/video42 ("thermal-net"), matching the host-side
# sender (thermal-to-hailo.sh) and falcon's camera config.
KERNEL_MODULE_AUTOLOAD += "v4l2loopback"
KERNEL_MODULE_PROBECONF += "v4l2loopback"
module_conf_v4l2loopback = "options v4l2loopback devices=1 video_nr=42 card_label=thermal-net exclusive_caps=0 max_buffers=8"

RPROVIDES:${PN} += "kernel-module-v4l2loopback"
