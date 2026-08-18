SUMMARY = "Stable /dev names for the wraith drone's USB serial peripherals"
DESCRIPTION = "udev rules mapping the ArduPilot FC to /dev/fc and the mLRS Rx to \
/dev/mlrs by vendor:product id, so every drone presents identical device names and \
one mavlink-router config works fleet-wide."
LICENSE = "CLOSED"

SRC_URI = "file://99-wraith.rules"
S = "${WORKDIR}"

RDEPENDS:${PN} = "udev"

do_install() {
    install -d ${D}${sysconfdir}/udev/rules.d
    install -m 0644 ${WORKDIR}/99-wraith.rules ${D}${sysconfdir}/udev/rules.d/99-wraith.rules
}

FILES:${PN} = "${sysconfdir}/udev/rules.d/99-wraith.rules"
