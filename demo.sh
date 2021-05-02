#!/bin/sh

#
# DEMO.sh - Spin up the Arch Linux installer with a 10G disk and usermode networking
#

# Load the sauce
source $(dirname $0)/lib/qemuonrails.sh

# Create System Disks - this is a simple flat file and installer ISO example
data_create() {
	# The root disk is a 10G flat file
	local rootdisk="$DATADIR/vm.${VMNAME}.root"
	[ -f "$rootdisk" ] || truncate -s 10G "$rootdisk" # create empty disk file
	DISK_ARGS="${DISK_ARGS} -drive file=$rootdisk,if=virtio,format=raw"

	# Picking on gentoo because the iso is small...
	local installdisk="$DATADIR/gentoo.iso"
	[ -f "$installdisk" ] || curl -o $installdisk 'http://mirrors.edge.kernel.org/archlinux/iso/2021.05.01/archlinux-2021.05.01-x86_64.iso'
	DISK_ARGS="${DISK_ARGS} -cdrom $installdisk"
}

# Create the network adapter - this is a simple nat / user networking example
net_create() {
	NET_ARGS=""
	NET_ARGS="${NET_ARGS} -netdev user,id=n1 -device virtio-net-pci,netdev=n1"
}

command_handler "$@"
