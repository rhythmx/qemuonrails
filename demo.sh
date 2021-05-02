#!/bin/bash

#
# DEMO.sh - Spin up the Arch Linux installer with a 10G disk and usermode networking
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
	echo "License: "
}

# Take the name of the vm from the script.. this makes it easy to copy the scripts and then recreate a new clone
VMNAME=$(basename "$0" .sh| sed -e s/[[:space:]]//g)
RUNDIR="/run/qemu/${VMNAME}"
DATADIR="/var/qemu/${VMNAME}"

# Create System Disks - this is a simple flat file and installer ISO example
disk_setup() {
	DISK_ARGS=""
	
	# The root disk is a 10G flat file
	local rootdisk="$DATADIR/vm.${VMNAME}.root"
	[ -f "$rootdisk" ] || dd if=/dev/zero of=$rootdisk bs=4k count=10240
	DISK_ARGS="${DISK_ARGS} -drive file=$rootdisk,if=virtio,format=raw"

	# Picking on gentoo because the iso is small...
	local installdisk="$DATADIR/gentoo.iso"
	[ -f "$installdisk" ] || curl -o $installdisk 'http://mirrors.edge.kernel.org/archlinux/iso/2021.05.01/archlinux-2021.05.01-x86_64.iso'
	DISK_ARGS="${DISK_ARGS} -cdrom $installdisk"
}


# Delete any disks created by `disk_setup`
disk_cleanup() {
	rm -fr "$DATADIR"
	rm -rf "$RUNDIR"
}

# Create the network adapter - this is a simple nat / user networking example
if_setup() {
	NET_ARGS=""
	NET_ARGS="${NET_ARGS} -netdev user,id=n1 -device virtio-net-pci,netdev=n1"
}

# Delete any network resources created by `if-setup`
if_cleanup() {
	return # nothing to clean up
}

# Create a place for scratch/status files for when QEMU is running 
tmpfiles_setup() {
	mkdir -p "$RUNDIR"
	mkdir -p "$DATADIR"
}

# Release all temporary status files
tmpfiles_cleanup() {
	rm -rf "$RUNDIR/*"
}

# Launch QEMU - here it is launched in a GNU Screen session so the console can be attached to at will
launch_qemu() {
	# At a minimum, the -pidfile, -nographic, and -monitor options are required for the script to operate properly. Feel free to fiddle with the restof them.
	QEMU_ARGS=""
	QEMU_ARGS="${QEMU_ARGS} -pidfile ${RUNDIR}/${VMNAME}.pid"
	QEMU_ARGS="${QEMU_ARGS} -name ${VMNAME}"
	QEMU_ARGS="${QEMU_ARGS} -cpu host"
	QEMU_ARGS="${QEMU_ARGS} --enable-kvm"
	QEMU_ARGS="${QEMU_ARGS} -m 2G"
	QEMU_ARGS="${QEMU_ARGS} -nographic"
	QEMU_ARGS="${QEMU_ARGS} -vga qxl"
	QEMU_ARGS="${QEMU_ARGS} -vnc none" # vnc=none allows you to use the monitor console to enable VNC later on the fly
	QEMU_ARGS="${QEMU_ARGS} ${DISK_ARGS}"
	QEMU_ARGS="${QEMU_ARGS} ${NET_ARGS}"
	QEMU_ARGS="${QEMU_ARGS} -qmp unix:${RUNDIR}/qmp-sock,server,nowait"
	QEMU_ARGS="${QEMU_ARGS} -monitor unix:${RUNDIR}/mon-sock,server,nowait"
	QEMU_ARGS="${QEMU_ARGS} -serial mon:stdio"
	QEMU_CMD="qemu-system-x86_64 ${QEMU_ARGS}"

	LAUNCH_CMD="/usr/bin/screen -d -m -S ${VMNAME} -- ${QEMU_CMD}"
	
	if [ -f "$RUNDIR/${VMNAME}.pid" ]; then
		echo "this vm is already running!"
		return
	fi
		
	# expand the command and exec
	$LAUNCH_CMD
}

# This waits until QEMU exits, then automatically cleans up temporal resources
wait_for_qemu() {
	tmpfiles_setup
	if [ -f "$RUNDIR/${VMNAME}.pid" ]; then
		local pid=$(< "$RUNDIR/$VMNAME.pid")
		tail --pid=$pid -f /dev/null # `wait` won't work because QEMU isn't a child proc of this shell
	else
		echo "The VM is not running (no pidfile)"
	fi
	if_cleanup
	tmpfiles_cleanup
}

# Pipes a command to the QEMU monitor and filters out everything but the response
monitor_command() {
	echo "$@" | 
		socat UNIX-CONNECT:$RUNDIR/mon-sock - | 
		grep -Pv '^QEMU \d+.\d+.\d+' | 
		grep -Pv '^\(qemu\)'
}

# Clean up all persistent storage
delete_vm() {
	echo -n "This will permanently delete VM resources, are you sure? [y/N] "
	read resp
	if [ "$resp" = "y" ]; then 
		if is_running; then
			monitor_command "quit"
			wait_for_qemu
		fi
		disk_cleanup
		if_cleanup
	else
		echo "skipping."
	fi
}

# Cross-check the pid file and active processes
is_running() {
	if [ -f "$RUNDIR/${VMNAME}.pid" ]; then
		local qpid=$(< "$RUNDIR/$VMNAME.pid")
		if ! [ -d /proc/$qpid ]; then
			echo "VM is no longer running, cleaning up stale RUNDIR"
			return 1
		fi
		return 0
	fi
	return 1
}

# Sanity check
exit_if_not_running() {
	if ! is_running; then
		echo "vm is not running"
		exit 1
	fi
}

# Handle user command
case "$1" in 
	start)
		# Start QEMU in a GNU Screen session and return
		tmpfiles_setup
		disk_setup
		if_setup
		launch_qemu
		;;
	run)
		# Start _and_ wait until VM exits
		tmpfiles_setup
		disk_setup
		if_setup
		launch_qemu
		wait_for_qemu
		;;
	wait)
		# Wait for QEMU to exit and clean up
		wait_for_qemu
		;;
	status)
		# Print out current QEMU status: running, paused, etc
		exit_if_not_running
		monitor_command info status	
		;;
	create)
		# Build up any resident VM resources 
		tmpfiles_setup
		disk_setup
		;;
	command)
		# run the given command
		exit_if_not_running
		shift
		monitor_command "$@"
		;;
	monitor)
		# start the monitor console
		exit_if_not_running
		rlwrap -C qmp socat STDIO UNIX:$RUNDIR/mon-sock 
		;;
	shutdown)
		# Power off the guest (works like pushing the power button, the guest has a chance to do so gracefully)
		exit_if_not_running
		monitor_command "system_powerdown"
		;;
	reboot)
		# Reset the guest
		exit_if_not_running
		monitor_command "system_reset"
		;;
	delete)
		# delete the vm resources from the disk PERMANENTLY
		delete_vm
		;;
	*)
		usage
		exit 1
esac

