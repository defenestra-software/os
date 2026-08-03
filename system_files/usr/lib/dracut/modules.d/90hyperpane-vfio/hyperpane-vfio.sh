#!/bin/sh
# Binds the PCI devices listed in the hyperpane.vfio= karg to vfio-pci

type getargs > /dev/null 2>&1 || . /lib/dracut-lib.sh

addrs=$(getargs hyperpane.vfio= | tr ',' ' ')
if [ -n "$addrs" ]; then
    modprobe -i vfio-pci 2> /dev/null || :
    for addr in $addrs; do
        [ -e "/sys/bus/pci/devices/$addr" ] || continue
        echo vfio-pci > "/sys/bus/pci/devices/$addr/driver_override"
        echo "$addr" > /sys/bus/pci/drivers_probe 2> /dev/null || :
    done
fi
