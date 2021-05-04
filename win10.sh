#!/bin/bash

#
# Win10.sh - Starts up a Windows 10 VM with some Hyper-V tuning
#

# Load the sauce
source $(dirname $0)/lib/qemuonrails.sh

QEMU_MEM="-m 8G"
# See https://github.com/qemu/qemu/blob/master/docs/hyperv.txt
QEMU_KVM="-enable-kvm -cpu host,hv_relaxed,hv_spinlocks=0x1fff,hv_vapic,hv_time" 
QEMU_CPU="-smp cpus=4"
QEMU_VID="-vga virtio"
QEMU_EXT="-audiodev pa,id=snd0 -device ich9-intel-hda -device hda-output,audiodev=snd0" # untested

# Create System Disks - this is a simple flat file and installer ISO example
data_create() {

        # / is 32GB raid0 x2 ssd gotta go fast
        local rootdisk="vm.${VMNAME}.root"
        if ! lvdisplay vg0/$rootdisk >/dev/null 2>&1; then
                lvcreate -y --type raid0 -L 32G --stripes 2 --stripesize 4 -n $rootdisk vg0 /dev/nvme0n1p4 /dev/nvme1n1p4
        fi
        DISK_ARGS="${DISK_ARGS} -drive file=/dev/vg0/$rootdisk,if=virtio,format=raw,aio=native,cache=none"

	# Up to you to find a Windows ISO
	local installdisk="/home/sean/Windows10.iso"
	if ! [ -f "$installdisk" ]; then
		echo "Windows 10 Installer ISO not found, please update"
		exit 1
	fi
	DISK_ARGS="${DISK_ARGS} -cdrom $installdisk"

	# Tack on a driver cd with virtio drivers because Windows will not know what to do with them
	local virtiodisk="/home/sean/virtio.iso"
	if ! [ -f "$virtiodisk" ]; then
		# Note... use of curl seems to trigger a 303, you'll probably have to download this manually
	 	curl -o "$virtiodisk" https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.185-2/virtio-win.iso
	fi
	DISK_ARGS="${DISK_ARGS} -drive file=$virtiodisk,index=3,media=cdrom"
}

data_delete() {
        local rootdisk="vm.${VMNAME}.root"
	lvremove -y vg0/$rootdisk
}

# Create the network adapter - this is a simple nat / user networking example
net_create() {
	NET_ARGS="${NET_ARGS} -netdev user,id=n1 -device virtio-net-pci,netdev=n1"
}

command_handler "$@"
