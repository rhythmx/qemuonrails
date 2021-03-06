#!/bin/bash

#
# DEMO.sh - Spin up a simple alpine x86_64 example with a 10G raw disk and usermode networking
#

# Load the sauce
. $(dirname $0)/lib/qemuonrails.sh

# load bundled libraries
include platforms
include disk
include network

# configure platform 
platform   native
memory     2G
processors 2

# Setup disks
disk  raw -name "rootfs" -size 10G -if virtio
cdrom -url "https://dl-cdn.alpinelinux.org/alpine/v3.13/releases/x86_64/alpine-standard-3.13.5-x86_64.iso"

# Create the network adapter
network virtio_user

# Handle the user arguments (create / start / monitor / shutdown / delete / etc)
command_handler "$@"
