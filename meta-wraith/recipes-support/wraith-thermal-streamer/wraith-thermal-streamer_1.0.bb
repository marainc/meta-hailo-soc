SUMMARY = "Publishes the onboard USB camera to a stable /dev/video33"
DESCRIPTION = "Owns the onboard USB camera and republishes it to the v4l2loopback node \
/dev/video33, so consumers (falcon) open one fixed device regardless of which \
/dev/videoN the camera lands on across reboots. Self-heals: retries while the camera \
is absent and restarts the pipeline if it dies."
LICENSE = "CLOSED"

SRC_URI = "file://thermal_streamer.sh \
           file://thermal-streamer.init \
"
S = "${WORKDIR}"

inherit update-rc.d

INITSCRIPT_NAME = "thermal-streamer"
# After udev has settled so the camera node exists; before falcon.
INITSCRIPT_PARAMS = "defaults 85 15"

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${WORKDIR}/thermal_streamer.sh ${D}${bindir}/wraith-thermal-streamer

    install -d ${D}${sysconfdir}/init.d
    install -m 0755 ${WORKDIR}/thermal-streamer.init ${D}${sysconfdir}/init.d/thermal-streamer
}

RDEPENDS:${PN} = "\
    kernel-module-v4l2loopback \
    v4l-utils \
    gstreamer1.0 \
    gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-base \
"
