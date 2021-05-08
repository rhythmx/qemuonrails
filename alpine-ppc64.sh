#!/bin/sh

#
# AlpinePPC.sh - Spin up a PPC emulator with Alpine Linux
#

# Load the sauce
source $(dirname $0)/lib/qemuonrails.sh

# load bundled libraries
include platforms
include disk
include network

# configure platform 
platform   ppc64
memory     2G
processors 2

# Setup disks
disk qcow -name "rootfs" -size 10G
cdrom -url 'https://dl-cdn.alpinelinux.org/alpine/v3.13/releases/ppc64le/alpine-standard-3.13.5-ppc64le.iso'

# Setup network
network virtio_user

command_handler "$@"
