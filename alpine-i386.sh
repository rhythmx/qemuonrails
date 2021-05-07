#!/bin/bash

#
# DEMO.sh - Spin up a simple alpine example with a 10G disk and usermode networking
#

# Load the sauce
. $(dirname $0)/lib/qemuonrails.sh

# load bundled libraries
include platforms
include disk
include network

# configure platform 
platform   i386 
memory     2G
processors 2

# Setup disks
disk  virtio_new  "rootfs" 10G
cdrom virtio_file "https://dl-cdn.alpinelinux.org/alpine/v3.13/releases/x86/alpine-standard-3.13.5-x86.iso"

# Create the network adapter
network virtio_user

# Handle the user arguments (create / start / monitor / shutdown / delete / etc)
command_handler "$@"
