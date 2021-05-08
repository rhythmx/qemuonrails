#!/bin/sh

#
# hugepages.sh - Quick example of using hugetlbfs for optimized guest memory
#

# Load the sauce
source $(dirname $0)/lib/qemuonrails.sh

# load bundled libraries
include platforms
include disk
include network

# configure platform 
platform   native
memory     2G
processors 2

# This is the only thing qemu needs, see https://wiki.archlinux.org/title/KVM 
# for quick instructions on mounting hugetlbfs. You'll also want to make sure 
# you set the number of huge pages to something > the ram you're consuming as 
# well. `echo 5500 > /proc/sys/vm/nr_hugepages` will pre-allocate 10G+ of ram 
QEMU_MEM="-m 1G -mem-path /dev/hugepages"

# Setup disks
disk  raw -name "rootfs" -size 10G -if virtio
cdrom -url "https://dl-cdn.alpinelinux.org/alpine/v3.13/releases/x86_64/alpine-standard-3.13.5-x86_64.iso"

# Create the network adapter
network virtio_user

command_handler "$@"
