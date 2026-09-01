SUMMARY = "Python MAVLink implementation"
DESCRIPTION = "MAVLink protocol library for Python. Used on-board for flight-controller \
diagnostics and parameter work (reading prearm state, relay status, GPS health) without \
needing a ground station."
HOMEPAGE = "https://github.com/ArduPilot/pymavlink"
LICENSE = "LGPL-3.0-only"
LIC_FILES_CHKSUM = "file://COPYING;md5=6ea13ec5f0f3dd35ac5b53afdc3ed9ff"

SRC_URI[sha256sum] = "d7cf10d5592d038a18aa972711177ebb88be2143efcc258df630b0513e9da2c2"

PYPI_PACKAGE = "pymavlink"

inherit pypi setuptools3

# setup.py runs mavgen to generate the dialect modules at build time.
DEPENDS += "python3-future-native python3-lxml-native"

RDEPENDS:${PN} += "\
    python3-core \
    python3-io \
    python3-json \
    python3-math \
    python3-pyserial \
    python3-future \
"
