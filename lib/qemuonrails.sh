#!/bin/bash

#
# LVM.sh - Spin up using LVM RAID with LVM Cacheing and Bridge Networking with VLAN filtering
#

usage() {
	echo "Usage: vmname.sh (start | run | wait | status | create | command | monitor | shutdown | reboot | delete)"
	echo "Management util for creating/launching/monitoring a QEMU virtual machine"
	echo ""
	echo "Commands:"
	echo "  start:    run this virtual machine and return"
	echo "  run:      run this virtual machine and wait until it powers off"
	echo "  wait:     wait until the VM powers off and then cleanup"
	echo "  status:   show the VMs current run status"
  	echo "  create:   create new virtual disks and anyh other one-time setup"
	echo "  command:  run a monitor command (like 'info vnc' or 'device add ...')"
	echo "  monitor:  start a monitor shell (^D to exit, 'quit' will terminate the VM)"
	echo "  shutdown: shutdown the VM gracefully (like short-pressing the power button)"
	echo "  reboot:   reset the VM"
	echo "  delete:   delete the disks and any other persistent resources"
	echo ""
	echo "Customizing:"
	echo "  The general idea here is to edit the 'disk_setup', 'if_setup' and 'launch_qemu' "
	echo "  functions defined in this script. Once the VM is configured the way you like it,"
	echo "  all of the commands above are automatically available. You can also use this "
	echo "  script in conjunction with systemd units in order to automatically launch and "
	echo "  manage virtual machines at OS boot. Have a look at the examples." 
	echo ""
	echo "License: BSD 3-clause"
}

# Take the name of the vm from the script.. this makes it easy to copy the scripts and then recreate a new clone
VMNAME=$(basename "$0" .sh| sed -e s/[[:space:]]//g)
RUNDIR="/run/qemu/${VMNAME}"
DATADIR="/var/qemu/${VMNAME}"


# By default don't create files accessible by others
umask 077

# Create System Disks - this is an advanced LVM example
data_create_wrap() {
	DISK_ARGS=""
	install -d -m 700 "$DATADIR"
	# create auto-disks if defined
	if [ "$(command -v "disk_autocreate")x" != "x" ]; then
		disk_autocreate
	fi
	data_create
}
data_create() { return; } # user override stub

# Delete any disks created by `disk_setup`
data_delete_wrap() {
	data_delete
	rm -rf "$DATADIR"
	rm -rf "$RUNDIR"
}
data_delete() { return; } # user override stub

# Create the network adapter - this is an advanced bridging w/ vlan example
net_create_wrap() {
	NET_ARGS=""
	net_create
}
net_create() { return; } # user override stub

# Delete any network resources created by `if-setup`
net_delete_wrap() {
	net_delete
}
net_delete() { return; } # user override stub

# Create a place for scratch/status files for when QEMU is running 
runfiles_create_wrap() {
	install -d -m 700 "$RUNDIR"
	runfiles_create
}
runfiles_create() { return; } # user override stub

# Release all temporary status files
runfiles_delete_wrap() {
	rm -rf $RUNDIR/*
}
runfiles_delete() { return; }

# Launch QEMU - here it is launched in a GNU Screen session so the console can be attached to at will
qemu_launch_wrap() {
	# At a minimum, the -pidfile, -nographic, and -monitor options are required for the script to operate properly. Feel free to fiddle with the restof them.
	QEMU_ARGS=""
	QEMU_ARGS="${QEMU_ARGS} -pidfile ${RUNDIR}/${VMNAME}.pid"
	QEMU_ARGS="${QEMU_ARGS} -name ${VMNAME}"
	QEMU_ARGS="${QEMU_ARGS} ${QEMU_KVM}"
	QEMU_ARGS="${QEMU_ARGS} ${QEMU_CPU}"
	QEMU_ARGS="${QEMU_ARGS} ${QEMU_MEM}"
	QEMU_ARGS="${QEMU_ARGS} ${QEMU_VID}"
	QEMU_ARGS="${QEMU_ARGS} ${QEMU_VNC}" # vnc=none allows you to use the monitor console to enable VNC later on the fly
	QEMU_ARGS="${QEMU_ARGS} ${QEMU_EXT}"
	QEMU_ARGS="${QEMU_ARGS} ${DISK_ARGS}"
	QEMU_ARGS="${QEMU_ARGS} ${NET_ARGS}"
	QEMU_ARGS="${QEMU_ARGS} -nographic"
	QEMU_ARGS="${QEMU_ARGS} -qmp unix:${RUNDIR}/qmp-sock,server,nowait"
	QEMU_ARGS="${QEMU_ARGS} -monitor unix:${RUNDIR}/mon-sock,server,nowait"
	QEMU_ARGS="${QEMU_ARGS} -serial mon:stdio"

	qemu_launch
	
	LAUNCH_CMD="/usr/bin/screen -d -m -S ${VMNAME} -- ${QEMU_BIN} ${QEMU_ARGS}"
	
	if qemu_is_running; then
		echo "this vm is already running!"
		return
	fi

	# expand the command and exec
	$LAUNCH_CMD

	# wait for pid file to be created 
	local timeout_ms=0
	while ! qemu_is_running; do
		sleep 0.1
		timeout_ms=$(( timeout_ms + 100 ))
		if [ "$timeout_ms" -gt 5000 ]; then
			echo "timed out waiting for PID file to be created"
			return 1
		fi
	done 
}
qemu_launch() { return; } # user override stub

# This waits until QEMU exits, then automatically cleans up temporal resources
qemu_wait() {
	runfiles_create
	if [ -f "$RUNDIR/${VMNAME}.pid" ]; then
		local pid=$(< "$RUNDIR/$VMNAME.pid")
		tail --pid=$pid -f /dev/null # `wait` won't work because QEMU isn't a child proc of this shell
	else
		echo "The VM is not running (no pidfile)"
	fi
	net_delete
	runfiles_delete
}

# Pipes a command to the QEMU monitor and filters out everything but the response
monitor_command() {
	echo "$@" | 
		socat UNIX-CONNECT:$RUNDIR/mon-sock - | 
		grep -Pv '^QEMU \d+.\d+.\d+' | 
		grep -Pv '^\(qemu\)'
}

# Clean up all persistent storage
delete_command() {
	echo -n "This will permanently delete VM resources, are you sure? [y/N] "
	read resp
	if [ "$resp" = "y" ]; then 
		if qemu_is_running; then
			monitor_command "quit"
			qemu_wait
		fi
		data_delete_wrap
		net_delete_wrap
	else
		echo "skipping."
	fi
}

# Cross-check the pid file and active processes
qemu_is_running() {
	if [ -f "$RUNDIR/${VMNAME}.pid" ]; then
		local qpid=$(< "$RUNDIR/$VMNAME.pid")
		if ! [ -d /proc/$qpid ]; then
			runfiles_delete_wrap
			echo "VM is no longer running, cleaning up stale RUNDIR"
			return 1
		fi
		return 0
	fi
	return 1
}

# Sanity check
fail_if_not_running() {
	if ! qemu_is_running; then
		echo "vm is not running"
		exit 1
	fi
}

# Handle user command
command_handler() {
	case "$1" in 
		start)
			# Start QEMU in a GNU Screen session and return
			command_handler create
			net_create_wrap
			qemu_launch_wrap
			;;
		run)
			# Start _and_ wait until VM exits
			command_handler start
			command_handler wait
			;;
		wait)
			# Wait for QEMU to exit and clean up
			qemu_wait
			;;
		status)
			# Print out current QEMU status: running, paused, etc
			fail_if_not_running
			monitor_command info status	
			;;
		create)
			# Build up any resident VM resources 
			runfiles_create_wrap
			data_create_wrap
			;;
		command)
			# run the given command
			fail_if_not_running
			shift
			monitor_command "$@"
			;;
		monitor)
			# start the monitor console
			fail_if_not_running
			rlwrap -C qmp socat STDIO UNIX:$RUNDIR/mon-sock 
			;;
		shutdown)
			# Power off the guest (works like pushing the power button, the guest has a chance to do so gracefully)
			fail_if_not_running
			monitor_command "system_powerdown"
			;;
		reboot)
			# Reset the guest
			fail_if_not_running
			monitor_command "system_reset"
			;;
		delete)
			# delete the vm resources from the disk PERMANENTLY
			delete_command
			;;
		*)
			usage
			exit 1
	esac	
}

# Add some syntax sugar to include other library files
include() {
	local file="$(dirname $0)/lib/$1.sh"
	if [ -f "$file" ]; then 
		. "$file"
	else 
		echo "include: not found: $1"
		exit 1
	fi	
}

# fatal uses SIGUSR1 to allow clean fatal errors from within 
trap "exit 1" 10
PROC=$$
fatal(){
  echo "$@" >&2
  kill -10 $PROC
}

include platforms
