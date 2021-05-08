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

# configure platform 
platform   win10 # same as "native" + some hyperv support
memory     8G
processors 4

# Setup disks
disk  qcow -name "cdrive" -size 64G -if virtio
cdrom -path "/home/sean/Windows10.iso" # Find your own iso
# Tack on a driver cd with virtio drivers because Windows will not know what to do with them
cdrom -path "/home/sean/virtio.iso" # Available here: https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.185-2/virtio-win.iso

# Create the network adapter
network virtio_user

command_handler "$@"
