network() {
    local nettype="$1"
    shift
    # posix sh compliant way to check for a function
    if [ "$(command -v "network_$nettype")x" != "x" ]; then
        "network_$nettype" "$@"
    else
        echo "network: type not found: $nettype"
        exit 1
    fi  
}

# Create Network Devices
network_autocreate() {

    local idx=0

    while [ "$idx" -lt "$NET_N_CFGS" ]; do
        local name=$(eval echo "\$NET${IDX}_NAME")
        local size=$(eval echo "\$NET${IDX}_SIZE")
        local type=$(eval echo "\$NET${IDX}_PATH")
        local type=$(eval echo "\$NET${IDX}_MEDIA")
        local type=$(eval echo "\$NET${IDX}_TYPE")
        "network_$type_autocreate" 
        idx=$(( idx + 1 ))
    done
}

network_virtio_user() {
    # This method doesn't create/use any system resources so  we can just set the args here passively, even if we aren't doing a 'create' operation
    NET_ARGS="${NET_ARGS} -netdev user,id=nic${NET_USER_NIC_N} -device virtio-net-pci,netdev=nic${NET_USER_NIC_N}"
    NET_USER_NIC_N=$(( NET_USER_NIC_N + 1 ))
}

# Global 
NET_N_CFGS=0
NET_USER_NIC_N=1

