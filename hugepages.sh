#!/bin/sh

#
# hugepages.sh - Quick example of using hugetlbfs for optimized guest memory
#

# Load the sauce
source $(dirname $0)/lib/qemuonrails.sh

# This is the only thing qemu needs, see https://wiki.archlinux.org/title/KVM 
# for quick instructions on mounting hugetlbfs. You'll also want to make sure 
# you set the number of huge pages to something > the ram you're consuming as 
# well. `echo 5500 > /proc/sys/vm/nr_hugepages` will pre-allocate 10G+ of ram 
QEMU_MEM="-m 1G -mem-path /dev/hugepages"

# Create System Disks - this is a simple flat file and installer ISO example
data_create() {
	# The root disk is a 10G qcow image file
	local rootdisk="$DATADIR/vm.${VMNAME}.root"
	[ -f "$rootdisk" ] || qemu-img create -f qcow2 "$rootdisk" 10G # create empty disk file
	DISK_ARGS="${DISK_ARGS} -hda $rootdisk"

	# Picking Alpine because the ISO is so small...
	QEMU_ARGS="${QEMU_ARGS} ${QEMU_CPU}"
	local installdisk="$DATADIR/alpine-standard-3.13.5-x86_64.iso"
	[ -f "$installdisk" ] || curl -o $installdisk 'https://dl-cdn.alpinelinux.org/alpine/v3.13/releases/x86_64/alpine-standard-3.13.5-x86_64.iso'
	DISK_ARGS="${DISK_ARGS} -cdrom $installdisk"
}

# Create the network adapter - this is a simple nat / user networking example
net_create() {
	NET_ARGS="${NET_ARGS} -netdev user,id=n1 -device virtio-net-pci,netdev=n1"
}

command_handler "$@"
