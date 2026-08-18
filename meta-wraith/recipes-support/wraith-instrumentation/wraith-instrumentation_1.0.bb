SUMMARY = "Board health blackbox recorder and temperature readout"
DESCRIPTION = "Persistent 10 s-cadence health log (die temps, input voltage, power, \
free memory, free disk, load, CPU freq) plus a per-boot dmesg capture — the forensics \
trail for unexplained reboots and thermal events. Also installs 'temp', a live SoC \
temperature readout."
LICENSE = "CLOSED"

SRC_URI = "file://hailo_thermal_watchdog.sh \
           file://hailo_temp_cmd.sh \
           file://hailo_blackbox.init \
"
S = "${WORKDIR}"

inherit update-rc.d

INITSCRIPT_NAME = "hailo-blackbox"
# Start early: this is the forensics recorder, it should be running before
# anything that might crash the board.
INITSCRIPT_PARAMS = "defaults 20 80"

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${WORKDIR}/hailo_thermal_watchdog.sh ${D}${bindir}/hailo-thermal-watchdog
    install -m 0755 ${WORKDIR}/hailo_temp_cmd.sh        ${D}${bindir}/temp

    install -d ${D}${sysconfdir}/init.d
    install -m 0755 ${WORKDIR}/hailo_blackbox.init ${D}${sysconfdir}/init.d/hailo-blackbox
}

RDEPENDS:${PN} = "\
    ${VIRTUAL-RUNTIME_base-utils} \
    procps \
"
