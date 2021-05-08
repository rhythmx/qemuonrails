# This code is going to be pretty specific to the local system, without much
# opportunity for reuse. It is provided as an example of best practices when
# creating site local libraries.

VOLGROUP="vg0"
SSD1=/dev/nvme0n1p4
SSD2=/dev/nvme1n1p4
HDD1=/dev/sda
HDD2=/dev/sdb

# Custom autodisk definition handler
disk_lvmraid() {
    local idx=$DASIZE
    DISK_ARGS[$idx,type]="lvmraid"

    while [ $# -gt 0 ]; do
        case $1 in
            -name)
                DISK_ARGS[$idx,name]=$(disk_validate_name $2)
                shift
                ;;
            -mode)
                DISK_ARGS[$idx,mode]=$(lvmraid_validate_mode $2)
                shift
                ;;
            -size)
                DISK_ARGS[$idx,size]=$(disk_validate_size $2)
                shift
                ;;
            -cachesize)
                DISK_ARGS[$idx,cachesize]=$(disk_validate_size $2)
                shift
                ;;
            -cachemode)
                DISK_ARGS[$idx,cachemode]=$(lvmraid_validate_mode $2)
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
disk_lvmraid_create() {
    local idx=$1
    local name=${DISK_ARGS[$idx,name]}
    local mode=${DISK_ARGS[$idx,mode]}
    local size=${DISK_ARGS[$idx,size]}
    local cachesize=${DISK_ARGS[$idx,cachesize]}
    local cachemode=${DISK_ARGS[$idx,cachemode]}
    local ex=${DISK_ARGS[$idx,ex]}

    # Sanity checks
    if [ -z "$size" ] || [ -z "$name" ] || [ -z "$mode" ]; then
        fatal "must specify name, size, and raid mode"
    fi
    if [ -n "$cachemode" ] || [ -n "$cachesize" ]; then
        if [ -z "$cachemode" ] || [ -z "$cachesize" ]; then
            fatal "must specify both cachemode and cachesize when setting either"
        fi
    fi

    local diskname=$(lvmraid_diskname "$name")

    # Create the main disk
    lvmraid_create_mode "$mode" "$diskname" "$size"

    # Add LVM cache if requested
    if [ -n "$cachemode" ]; then
        lvmraid_create_mode "$cachemode" "$diskname.cache" "$cachesize"
        lvconvert -y --type cache --cachevol "$VOLGROUP/$diskname.cache" "$VOLGROUP/$diskname"
    fi 

    new_args="file=${diskname},if=virtio,format=raw"
    # add any extra args
    if [ -n "$ex" ]; then
        new_args="$new_args,$ex"
    fi
    QEMU_DISK_ARGS="$QEMU_DISK_ARGS -drive $new_args"
}

# Delete volumes when the "delete" command is invoked
disk_lvmraid_delete() {
    local idx=$1
    local name=$DISK_ARGS[$idx,name]
    local diskname=$(lvmraid_diskname "$name")
    lvmremove -y "$VOLGROUP/$diskname"
}

# Use a naming scheme organized by vm name
lvmraid_diskname() {
    local name=$1
    echo "vm.${VMNAME}.${name}"
}

lvmraid_create_mode() {
    local mode=$1
    local diskname=$2
    local size=$3

    # skip create if exists
    if lvdisplay ${VOLGROUP}/${diskname} >/dev/null 2>&1; then
        return
    fi

    case $mode in
        ssd_raid0)
            lvmcreate -y -type raid0 --stripes 2 --stripesize 4 -L "$size" -n "$diskname" "$VOLGROUP" "$SSD1" "$SSD2"
            ;;
        ssd_raid1)
            lvmcreate -y -type raid1 -m 1 -L "$size" -n "$diskname" "$VOLGROUP" "$SSD1" "$SSD2"
            ;;
        hdd_raid0)
            lvmcreate -y -type raid0 --stripes 2 --stripesize 4 -L "$size" -n "$diskname" "$VOLGROUP" "$HDD1" "$HDD2"
            ;;
        hdd_raid1)
            lvmcreate -y -type raid1 -m 1 -L "$size" -n "$diskname" "$VOLGROUP" "$HDD1" "$HDD2"
            ;;
        *)
            fatal "Unknown raid mode $mode"
    esac
}

lvmraid_validate_mode() {
    case $1 in
        ssd_raid1)
            echo $1
            ;; 
        ssd_raid0)
            echo $1
            ;;
        hdd_raid1)
            echo $1
            ;;
        hdd_raid0)
            echo $1
            ;;
        *)
            fatal "Unknown lvmraid mode $1"
    esac
}