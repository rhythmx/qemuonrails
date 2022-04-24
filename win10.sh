#!/bin/bash

#
# Win10.sh - Starts up a Windows 10 VM with some Hyper-V tuning
#

# Load the sauce
source $(dirname $0)/lib/qemuonrails.sh

# load bundled libraries
include platforms
include disk
include network

# include local custom libs
include site/lvmraid-hydra
include site/vlanbridge

# configure platform 
platform   windows10 # same as "native" + some hyperv support
memory     32G
processors 16,sockets=1,cores=8,threads=2

QEMU_MEM="-m 32G -mem-path /dev/hugepages"
# FOREGROUND=true # use qemu gui instead of headless in screen

# Setup disks
disk lvmraid -name "cdrive" -mode ssd_raid10 -size 128G -ex aio=native,cache=none
cdrom -path "$ISO_CACHE_DIR/Windows10.iso" # Find your own iso
# Tack on a driver cd with virtio drivers because Windows will not know what to do with them
cdrom -path "$ISO_CACHE_DIR/virtio.iso" # Available here: https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.185-2/virtio-win.iso

# Create the network adapter
network vlanbridge -vlan 41 # Work

command_handler "$@"
