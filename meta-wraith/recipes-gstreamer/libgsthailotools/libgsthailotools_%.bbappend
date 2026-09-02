# Vendor recipe rule: never edit meta-hailo-* files directly -- extend from here instead.
#
# The vendor do_install:append() hardcodes ${libdir}/gstreamer-1.0 (OE's libdir="/usr/lib"
# on this machine), but hailotools-base.bbclass never passes -Dlibdir to meson, so meson's
# own GNU-install-dirs autodetection installs the plugin to
# ${libdir}/aarch64-linux-gnu/gstreamer-1.0 instead -- leaving the vendor mv step looking
# in the wrong place:
#   mv: cannot stat '.../usr/lib/gstreamer-1.0/libgsthailotools.so.5.0.0': No such file or directory
# Force meson to use OE's libdir so the vendor do_install:append() finds what it expects.
EXTRA_OEMESON += "-Dlibdir='${libdir}'"
