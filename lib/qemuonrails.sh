#!/bin/bash

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
	echo "(C) 2021 - Sean Bradly, License: BSD-3"
}


# By default don't create files accessible by others
umask 077

# Create System Disks 
data_create_wrap() {
	QEMU_DISK_ARGS=""
	install -d -m 700 "$DATADIR"
	# create auto-disks if defined
	if fn_exists "disk_autocreate"; then
		disk_autocreate
	fi
	data_create
}
data_create() { return; } # user override stub

# Delete any disks created by `data_create*`
data_delete_wrap() {
	data_delete
	# delete auto-disks if defined
	if fn_exists "disk_autodelete"; then
		disk_autodelete
	fi
	rm -rf "$DATADIR"
	rm -rf "$RUNDIR"
}
data_delete() { return; } # user override stub

# Create the network adapter 
network_create_wrap() {
	QEMU_NET_ARGS=""
	if fn_exists "network_autocreate"; then
		network_autocreate
	fi
	network_create
}
network_create() { return; } # user override stub

# Delete any network resources created by `network_create*`
network_delete_wrap() {
	if fn_exists "network_autodelete"; then
		network_autodelete
	fi
	network_delete
}
network_delete() { return; } # user override stub

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
	QEMU_ARGS="${QEMU_ARGS} ${QEMU_MCH}"
	QEMU_ARGS="${QEMU_ARGS} ${QEMU_MEM}"
	QEMU_ARGS="${QEMU_ARGS} ${QEMU_VID}"
	QEMU_ARGS="${QEMU_ARGS} ${QEMU_VNC}" # vnc=none allows you to use the monitor console to enable VNC later on the fly
	QEMU_ARGS="${QEMU_ARGS} ${QEMU_EXT}"
	QEMU_ARGS="${QEMU_ARGS} ${QEMU_DISK_ARGS}"
	QEMU_ARGS="${QEMU_ARGS} ${QEMU_NET_ARGS}"
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
	if [ "$QEMU_DRY_RUN" != "t" ]; then
		$LAUNCH_CMD
	else
		echo $LAUNCH_CMD
		return
	fi

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
	runfiles_create_wrap
	if [ -f "$RUNDIR/${VMNAME}.pid" ]; then
		local pid=$(< "$RUNDIR/$VMNAME.pid")
		tail --pid=$pid -f /dev/null # `wait` won't work because QEMU isn't a child proc of this shell
	else
		echo "The VM is not running (no pidfile)"
	fi
	network_delete_wrap
	runfiles_delete_wrap
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
		network_delete_wrap
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
	# Take the name of the vm from the script.. this makes it easy to copy the scripts and then recreate a new clone
	# TODO: don't overwrite these if already set so scripts can redefine them	
	VMNAME=$(basename "$0" .sh| sed -e s/[[:space:]]//g)
	RUNDIR="/run/qemu/${VMNAME}"
	QEMUDIR="/var/qemu"
	DATADIR="${QEMUDIR}/${VMNAME}"
	ISO_CACHE_DIR="${QEMUDIR}/isos"

	case "$1" in 
		start)
			# Start QEMU in a GNU Screen session and return
			command_handler create
			network_create_wrap
			qemu_launch_wrap
			;;
		run)
			# Start _and_ wait until VM exits
			command_handler start
			command_handler wait
			;;
		dryrun)
			# Same as "run" but only print the generated QEMU command
			QEMU_DRY_RUN=t
			command_handler run
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

#
# Required utility functions
#

# return true if the given function is defined
fn_exists() {
	local fnname=$1
	if [ "$(command -v "$fnname")x" != "x" ]; then
		return 0
	else
		return 1
	fi
}

# Add some syntax sugar to include other library files
include() {
	local file="$(dirname $0)/lib/$1.sh"
	if [ "$(dirname $1)" = site ]; then
		file="$(dirname $0)/$1.sh"
	fi 
	if [ -f "$file" ]; then 
		. "$file"
	else 
		fatal "include: not found: $1"
	fi	
}

# fatal uses SIGUSR1 to allow clean fatal errors from within subshells 
trap "exit 1" 10
PROC=$$
fatal(){
  echo "$@" >&2
  kill -10 $PROC
}

# Everything needs platform, so go ahead and include it
include platforms
