SUMMARY = "Per-drone identity and rootfs growth at boot"
DESCRIPTION = "The only things that cannot be baked into a shared fleet image: this \
drone's hostname and static IP, and growing the rootfs to fill whatever SD card the \
image was written to. Identity is read from /boot/wraith-identity.conf on the FAT boot \
partition, so it can be set from any machine with an SD card reader — no console or \
network access needed. Idempotent; runs every boot."
LICENSE = "CLOSED"

SRC_URI = "file://wraith-identity.sh \
           file://wraith-identity.init \
"
S = "${WORKDIR}"

inherit update-rc.d

INITSCRIPT_NAME = "wraith-identity"
# rcS, before networking brings up the interfaces file this writes.
INITSCRIPT_PARAMS = "start 08 S ."

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${WORKDIR}/wraith-identity.sh ${D}${bindir}/wraith-identity

    install -d ${D}${sysconfdir}/init.d
    install -m 0755 ${WORKDIR}/wraith-identity.init ${D}${sysconfdir}/init.d/wraith-identity
}

# sfdisk/partx/blockdev from util-linux, resize2fs from e2fsprogs
RDEPENDS:${PN} = "\
    util-linux-sfdisk \
    util-linux-partx \
    util-linux-blockdev \
    e2fsprogs-resize2fs \
"
