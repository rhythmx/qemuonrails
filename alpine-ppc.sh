#!/bin/sh

#
# AlpinePPC.sh - Spin up a PPC emulator with Alpine Linux
#

# Load the sauce
source $(dirname $0)/lib/qemuonrails.sh

QEMU_BIN="qemu-system-ppc64"
QEMU_MEM="-m 1G"
QEMU_KVM=""
QEMU_VID="-vga std"
QEMU_EXT="-machine cap-htm=off"

# Create System Disks - this is a simple flat file and installer ISO example
data_create() {
	# The root disk is a 10G QCOW2 image file
	local rootdisk="$DATADIR/vm.${VMNAME}.root"
	[ -f "$rootdisk" ] || qemu-img create -f qcow2 "$rootdisk" 10G # create empty disk file
	DISK_ARGS="${DISK_ARGS} -hda $rootdisk"

	# Picking Alpine because the ISO is so small...
	QEMU_ARGS="${QEMU_ARGS} ${QEMU_CPU}"
	local installdisk="$DATADIR/alpine-standard-3.13.5-ppc64le.iso"
	[ -f "$installdisk" ] || curl -o $installdisk 'https://dl-cdn.alpinelinux.org/alpine/v3.13/releases/ppc64le/alpine-standard-3.13.5-ppc64le.iso'
	DISK_ARGS="${DISK_ARGS} -cdrom $installdisk"
}

# Create the network adapter - this is a simple nat / user networking example
net_create() {
	NET_ARGS="${NET_ARGS} -netdev user,id=n1 -device virtio-net-pci,netdev=n1"
}

command_handler "$@"
