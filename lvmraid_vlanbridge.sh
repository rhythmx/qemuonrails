#!/bin/sh

#
# lvmraid_bridgevlan.sh - More involved example showing how to use custom
# libraries to create and optimized LVM setup and the use of VLANFiltering with
# Linux bridging
#

# Load the sauce
source $(dirname $0)/lib/qemuonrails.sh

# load bundled libraries
include platforms
include disk
include network

# Load local custom libraries
include site/lvmraid
include site/vlanbridge

# configure platform 
platform   native
memory     2G
processors 2

# Setup disks
disk lvmraid -name "root" -mode hdd_raid1 -size 64G -cachemode ssd_raid0 -cachesize 512M
disk lvmraid -name "swap" -mode ssd_raid0 -size 2G 

# Setup Networks (in this case add a nic for each vlan)
network vlanbridge -vlan 1   # mgmt
network vlanbridge -vlan 41  # work
network vlanbridge -vlan 101 # home
network vlanbridge -vlan 110 # IoT
network vlanbridge -vlan 200 # dmz

# Let the command line do it's thing
command_handler "$@"
