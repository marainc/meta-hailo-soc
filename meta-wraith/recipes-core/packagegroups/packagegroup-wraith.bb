SUMMARY = "MARA wraith drone runtime"
DESCRIPTION = "Everything a wraith drone's Hailo needs on top of the Hailo BSP, so a \
freshly flashed board is bring-up complete: kernel modules, falcon's runtime \
dependencies, the MAVLink router, and the on-board instrumentation."

PACKAGE_ARCH = "${MACHINE_ARCH}"

inherit packagegroup

RDEPENDS:${PN} = "\
    kernel-module-cdc-acm \
    kernel-module-v4l2loopback \
    boost-log \
    boost-thread \
    python3-pymavlink \
    python3-pyserial \
    v4l-utils \
    gstreamer1.0-plugins-good \
    dfu-util \
    mavlink-router \
    wraith-udev-rules \
    wraith-instrumentation \
    wraith-thermal-streamer \
    wraith-identity \
"
