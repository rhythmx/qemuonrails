# This bridge needs to be preconfigured with VLANFiltering enabled
VLANBR="vlanbr0"

network_vlanbridge() {
    local idx=$NASIZE
    NET_ARGS[$idx,type]="vlanbridge"

    while [ $# -gt 0 ]; do 
        case $1 in
            -name)
                NET_ARGS[$idx,name]=$(network_validate_name $2)
                shift
                ;;
            -mac) 
                NET_ARGS[$idx,mac]=$(vlanbridge_validate_mac $2)
                shift
                ;;
            -vlan)
                NET_ARGS[$idx,vlan]=$(vlanbridge_validate_vlan $2)
                shift
                ;;
            *) 
                fatal "unknown option: $1"
        esac
        shift
    done
    NASIZE=$(( NASIZE + 1 ))
}

network_vlanbridge_create() {
    local idx=$1
    local name=${NET_ARGS[$idx,name]}
    local mac=${NET_ARGS[$idx,mac]}
    local vlan=${NET_ARGS[$idx,vlan]}
    
    if [ -z "$name" ]; then 
        name=eth
    fi
    local ifname=$(vlanbridge_ifname "$name" "$idx")

    if [ -z "$mac" ]; then
        mac=$(vlanbridge_mac_from_name "$ifname")
    fi

    if [ -z "$vlan" ]; then
        fatal "Must specify the vlan id, wont default to the untagged mgmt vlan"
    fi

    # Skip if already created
    ip link list $ifname >/dev/null 2>&1 && return

    ip tuntap add dev $ifname mode tap
    ip link set dev $ifname address $mac
    ip link set $ifname up
    ip link set $ifname master $VLANBR
    bridge vlan add dev $ifname vid $vlan pvid untagged master

    new_args="-netdev tap,id=$ifname,script=no,downscript=no"
    new_args="${new_args} -device virtio-net-pci,netdev=$ifname"

    QEMU_NET_ARGS="${QEMU_NET_ARGS} ${new_args}"
}

network_vlanbridge_delete() {
    local idx=$1
    local name=${NET_ARGS[$idx,name]}
    if [ -z "$name" ]; then 
        name=eth
    fi
    local ifname=$(vlanbridge_ifname "$name" "$idx")
    ip link del ${ifname} >/dev/null 2>&1
}

# This is wonky because it needs to uniquely truncate to less than 16 characters, but still be descriptive as to the vm it is associated with and the fn on the vm
vlanbridge_ifname() {
    local name=$1
    local idx=$2
    local opt_vmname=$3
    if [ -z "$opt_vmname" ];  then
	local ifname=$( echo -n "${VMNAME}-${name}${idx}" | sed -e 's/_/-/g')
    else
	local ifname=$( echo -n "${opt_vmname}-${name}${idx}" | sed -e 's/_/-/g')
    fi
    local len=$(echo -n $ifname | wc -c) 
    if [ "$len" -gt 15 ]; then
        local vmlen=$(echo -n $VMNAME | wc -c)
	local overflow_len=$(( len - 15 )) 
	# echo "resulting interface name is too long (over by ${overflow_len} bytes, truncating."
	if [ "$vmlen" -gt "$overflow_len" ]; then
		vlanbridge_ifname $name $idx $(echo -n "${VMNAME}" | head -c $(( vmlen - overflow_len )))
		return
	else
		fatal "size overflow in automatic interface naming"
	fi
    fi
    echo $ifname
}

# Uses checksum of name to generate MAC address
vlanbridge_mac_from_name() {
    local name=$1
    local i=$(( 0x$(echo -n "${name}" | md5sum - | head -c 8) ))
    printf "00:11:e7:%02x:%02x:%02x" $(( i & 0xff )) $(( ( i >> 8 ) & 0xff)) $(( ( i >> 16 ) & 0xff))
}

vlanbrige_validate_mac() {
    local mac="$1"
    if ( echo $1 | grep -vP '^[0-9a-fA-F]{2}(:[0-9a-fA-F]{2}){5}$' >/dev/null 2>&1 ); then
        fatal "$1 is not a valid vlan mac"
    fi
    echo "$1"
}

vlanbridge_validate_vlan() {
    local vlan="$1"
    if ( echo $1 | grep -vP '^\d+$' >/dev/null 2>&1 ); then
        fatal "$1 is not a valid vlan id"
    fi
    echo "$1"
}
