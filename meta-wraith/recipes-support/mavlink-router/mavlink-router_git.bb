SUMMARY = "MAVLink router — fans one FC serial out to multiple endpoints"
DESCRIPTION = "Opens the flight controller's serial port once and routes MAVLink to \
several endpoints (falcon locally, the hangar over ethernet, the ground station over \
mLRS), with per-endpoint message filtering and on-board tlog recording. Replaces \
mavp2p, which cannot filter per endpoint."
HOMEPAGE = "https://github.com/mavlink-router/mavlink-router"
LICENSE = "Apache-2.0"
LIC_FILES_CHKSUM = "file://LICENSE;md5=93888867ace35ffec2c845ea90b2e16b"

# Pinned to the exact revision built and verified in flight-hardware acceptance
# (FC heartbeat through tcp:5760 on shoebill45 and harpy41, 2026-08-14).
SRC_URI = "gitsm://github.com/mavlink-router/mavlink-router.git;protocol=https;branch=master \
           file://mavlink-router.init \
           file://mavlink-router-main.conf \
           file://mavlink-router.volatiles \
"
SRCREV = "2362c620f483cef1edd574fb962a373a288e4b9e"
PV = "4+git${SRCPV}"

S = "${WORKDIR}/git"

inherit meson pkgconfig update-rc.d

# Upstream's meson.build looks up the systemd pkg-config when this is left at
# 'auto'; we are sysvinit, so pin it and drop the unit that gets installed.
EXTRA_OEMESON = "-Dsystemdsystemunitdir=${nonarch_libdir}/systemd/system"

INITSCRIPT_NAME = "mavlink-router"
# Start late: the FC and mLRS USB serial devices must have enumerated first.
INITSCRIPT_PARAMS = "defaults 90 10"

do_install:append() {
    # sysvinit distro — discard upstream's systemd unit. This leaves
    # ${nonarch_libdir} (/usr/lib) itself as an empty leftover dir, which QA
    # flags as installed-but-not-shipped, so clean it up too.
    rm -rf ${D}${nonarch_libdir}/systemd
    rmdir --ignore-fail-on-non-empty ${D}${nonarch_libdir}

    install -d ${D}${sysconfdir}/init.d
    install -m 0755 ${WORKDIR}/mavlink-router.init ${D}${sysconfdir}/init.d/mavlink-router

    install -d ${D}${sysconfdir}/mavlink-router
    install -m 0644 ${WORKDIR}/mavlink-router-main.conf ${D}${sysconfdir}/mavlink-router/main.conf

    # /var/log is a symlink to /var/volatile/log (tmpfs) on this rootfs, and QA
    # requires /var/volatile to stay empty in the shipped image -- so mav_logs
    # is created at boot via populate-volatile.sh instead of baked in here.
    install -d ${D}${sysconfdir}/default/volatiles
    install -m 0644 ${WORKDIR}/mavlink-router.volatiles ${D}${sysconfdir}/default/volatiles/99_mavlink-router
}

# The config references /dev/fc and /dev/mlrs, created by wraith-udev-rules.
RDEPENDS:${PN} = "wraith-udev-rules"

FILES:${PN} += "${sysconfdir}/mavlink-router ${sysconfdir}/default/volatiles/99_mavlink-router"
CONFFILES:${PN} = "${sysconfdir}/mavlink-router/main.conf"
