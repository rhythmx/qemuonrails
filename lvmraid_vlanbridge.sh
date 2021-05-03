#!/bin/sh

#
# lvmraid_bridgevlan.sh - More involved example showing an optimized LVM setup and the use of VLANFiltering with Linux bridging
# 

# Load the sauce
source $(dirname $0)/lib/qemuonrails.sh

# Create System Disks - this is an advanced LVM example
data_create() {

	# / is 32GB raid 1 on 2 HDDs backed by 512M raid0 cache over 2 ssds
	local rootdisk="vm.${VMNAME}.root"
	if ! lvdisplay vg0/$rootdisk >/dev/null 2>&1; then
		lvcreate -y --type raid1 -m 1 -L 32G -n $rootdisk vg0 /dev/sda /dev/sdb
		lvcreate -y --type raid0 -L 512M --stripes 2 --stripesize 4 -n $rootdisk.cache vg0 /dev/nvme0n1p4 /dev/nvme1n1p4
		lvconvert -y --type cache --cachevol vg0/$rootdisk.cache vg0/$rootdisk
	fi
	DISK_ARGS="${DISK_ARGS} -drive file=/dev/vg0/$rootdisk,if=virtio,format=raw,aio=native,cache=none"

	# swap is 2GB of raid0 over 2 ssds
	local swapdisk="vm.${VMNAME}.swap"
	if ! lvdisplay vg0/$swapdisk >/dev/null 2>&1; then
		lvcreate -y --type raid1 -m 1 -L 2G -n $swapdisk vg0 /dev/nvme0n1p4 /dev/nvme1n1p4
	fi
	DISK_ARGS="${DISK_ARGS} -drive file=/dev/vg0/$swapdisk,if=virtio,format=raw,aio=native,cache=none"
}


# Delete any disks created by `disk_setup`
data_delete() {
	lvremove -y vg0/vm.${VMNAME}.root
	lvremove -y vg0/vm.${VMNAME}.swap
	rm -fr "$DATADIR"
	rm -rf "$RUNDIR"
}

# Create the network adapter - this is an advanced bridging w/ vlan example
net_create() {
	local intf0="${VMNAME}0"
	ip link list $intf0 >/dev/null 2>&1 && return 
	ip tuntap add dev $intf0 mode tap
	ip link set dev $intf0 address 00:11:E7:01:00:01
	ip link set $intf0 up
	ip link set $intf0 master vlanbr0
	bridge vlan add dev $intf0 vid 1 pvid untagged master
	NET_ARGS="${NET_ARGS} -netdev tap,id=n1,ifname=$intf0,script=no,downscript=no"
	NET_ARGS="${NET_ARGS} -device virtio-net-pci,netdev=n1"
}

# Delete any network resources created by `if-setup`
net_delete() {
	ip link del ${VMNAME}0 >/dev/null 2>&1
}

# Let the command line do it's thing
command_handler "$@"
