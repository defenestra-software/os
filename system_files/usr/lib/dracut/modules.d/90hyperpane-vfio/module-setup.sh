#!/bin/bash
# Early VFIO binding for Hyperpane GPU passthrough. Hyperpane sets the
# hyperpane.vfio= karg (comma-separated PCI addresses); the pre-udev hook
# binds those devices to vfio-pci before any native driver can claim them.

check() {
    return 0
}

depends() {
    echo "kernel-modules"
}

installkernel() {
    hostonly='' instmods vfio vfio_iommu_type1 vfio-pci
}

install() {
    inst_hook pre-udev 00 "$moddir/hyperpane-vfio.sh"
}
