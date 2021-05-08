#!/bin/bash

declare -A -g NET_ARGS
NASIZE=0

network() {
    local nettype=$(network_validate_type $1)
    shift

    # Prefer custom handler, if defined
    if fn_exists "network_$nettype"; then
        "network_$nettype" "$@"
        return
    fi

    NET_ARGS[$NASIZE,type]="$nettype"

    while [ $# -gt 0 ]; do
        case $1 in
            *)
                fatal "Unknown network option: $1"
                ;;
        esac
    done

    NASIZE=$(( NASIZE + 1 ))
}

# Create Network Devices
network_autocreate() {
    local idx=0

    while [ $idx -lt $NASIZE ]; do
        local type=${NET_ARGS[$idx,type]}
        "network_${type}_create" $idx 
        idx=$(( idx + 1 ))
    done
}

# Delete Network Devices
network_autodelete() {
    local idx=0
    while [ $idx -lt $NASIZE ]; do
        local type=${NET_ARGS[$idx,type]}
        # not every type will have a delete function
        if fn_exists "network_${type}_delete"; then
            "network_${type}_delete" $idx
        fi 
        idx=$(( idx + 1 ))
    done
}

network_virtio_user_create() {
    local idx=$1
    # This method doesn't create/use any system resources so  we can just set the args here passively, even if we aren't doing a 'create' operation
    QEMU_NET_ARGS="${QEMU_NET_ARGS} -netdev user,id=nic${idx} -device virtio-net-pci,netdev=nic${idx}"
}

network_validate_type() {
    # posix sh compliant way to check for a function
    if ! fn_exists "network_$1_create" && ! fn_exists "network_$1"; then
        fatal "network: type not found: $1"
    fi    
    echo "$1"
}

network_validate_name() {
    if (echo "$1" | grep -vP '^\w+$' >/dev/null 2>&1); then
        fatal "not a valid name for a network interface: $1"
    fi
    echo $1
}
