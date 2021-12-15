# This code is going to be pretty specific to the local system, without much
# opportunity for reuse. It is provided as an example of best practices when
# creating site local libraries.

# Custom autodisk definition handler
disk_lvm() {
    local idx=$DASIZE
    DISK_ARGS[$idx,type]="lvm"

    while [ $# -gt 0 ]; do
        case $1 in
            -name)
                DISK_ARGS[$idx,name]=$(disk_validate_name $2)
                shift
                ;;
            -vg)
                DISK_ARGS[$idx,vg]=$(lvm_validate_vg $2)
                shift
                ;;
            -size)
                DISK_ARGS[$idx,size]=$(disk_validate_size $2)
                shift
                ;;
            -ex)
                DISK_ARGS[$idx,ex]="$ex"
                shift
                ;;
            *)
                fatal "Unknown option: $1"
        esac
        shift
    done
    DASIZE=$(( DASIZE + 1 ))
}

# Create disks when the "create" command is run
disk_lvm_create() {
    local idx=$1
    local name=${DISK_ARGS[$idx,name]}
    local vg=${DISK_ARGS[$idx,vg]}
    local size=${DISK_ARGS[$idx,size]}
    local ex=${DISK_ARGS[$idx,ex]}

    # Sanity checks
    if [ -z "$size" ] || [ -z "$name" ] || [ -z "$vg" ]; then
        fatal "must specify name, size, and volgroup"
    fi
    
    local diskname=$(lvm_diskname "$name")

    # skip create if exists
    if ! lvdisplay ${VOLGROUP}/${diskname} >/dev/null 2>&1; then
    	# Create the main disk
    	lvm_create "$diskname" "$size" "$vg"
    fi
    
    new_args=""
    # create an io thread per CPU, disks will be balanced across them 
    if [ -z "$IOTHREADS" ]; then
	    cores=$(lscpu | grep Core\(s\)\ per\ socket: | cut -d: -f2)
	    sockets=$(lscpu | grep Socket\(s\): | cut -d: -f2)
	    IOTHREADS=$((cores * sockets))
        if [ "$IOTHREADS" -gt "8" ]; then
            IOTHREADS=8 # TODO: at most limit this to the number of disks, but pick a quick max for now
        fi
	    for i in $(seq 0 $(( IOTHREADS - 1)) ); do
            new_args="$new_args -object iothread,id=io$i"
        done
    fi

    new_args="$new_args -device virtio-blk-pci,drive=drive$idx,num-queues=8,iothread=io$(( idx % IOTHREADS ))"
    new_args="$new_args -drive file=/dev/$vg/${diskname},if=none,id=drive$idx,format=raw"
    # add any extra args
    if [ -n "$ex" ]; then
        new_args="$new_args,$ex"
    fi
    QEMU_DISK_ARGS="$QEMU_DISK_ARGS $new_args"
}

# Delete volumes when the "delete" command is invoked
disk_lvm_delete() {
    local idx=$1
    local name=${DISK_ARGS[$idx,name]}
    local vg=${DISK_ARGS[$idx,vg]}
    local diskname=$(lvm_diskname "$name")
    lvremove -y "$vg/$diskname"
}

# Use a naming scheme organized by vm name
lvm_diskname() {
    local name=$1
    echo "vm.${VMNAME}.${name}"
}

lvm_create() {
    local diskname=$1
    local size=$2

    lvcreate -y  -L "$size" -n "$diskname" "$vg" 
}

lvm_validate_vg() {
    if vgs | tail +2 | awk -e '{print $1}' | grep $1 >/dev/null 2>&1; then
        echo $1
    else
        fatal "Seemingly invalid volume group '$1' specified"
    fi
}
