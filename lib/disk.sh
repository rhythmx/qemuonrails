#!/bin/bash

# Global args array to share parsing -- "fake" multidemensional array v[12,key] where 12,key is actually the key 
declare -A -g DISK_ARGS
DASIZE=0

# Syntax sugar for disk creation - the complication here is that any real code
# only runs when the "create" (or "delete") command is called, in every other
# case it should just save the arguments so that the disks are "defined"  
disk() {
    local disktype=$(disk_validate_type "$1")
    shift

    local i=$DASIZE

    # prefer custom arg handler, if defined
    if fn_exists "disk_$disktype"; then
        "disk_$disktype" "$@"
        return
    fi

    # First argument should be type
    DISK_ARGS["$i,type"]="$disktype"

    while [ $# -gt 0 ]; do
        case $1 in
            -name)
                DISK_ARGS["$i,name"]=$(disk_validate_name "$2")
                shift
                ;;
            -size)
                # Size implies create new
                DISK_ARGS["$i,size"]=$(disk_validate_size "$2")
                shift
                ;;
            -url)
                DISK_ARGS["$i,url"]=$(disk_validate_url "$2")
                shift
                ;;
            -path)
                DISK_ARGS["$i,path"]=$(disk_validate_path "$2")
                shift
                ;;
            -if)
                # No validation because this can be relatively free form
                DISK_ARGS["$i,if"]="$2" 
                shift
                ;;
            -media)
                DISK_ARGS["$i,media"]=$(disk_validate_media "$2")
                shift 
                ;;
            -ex)
                DISK_ARGS["$i,ex"]="$2" # free form extra arguments
                shift
                ;;
            *) 
                fatal "Unknown disk option: $1"
        esac
        shift
    done
    # set the next valid index
    DASIZE=$(( DASIZE + 1 ))
}

cdrom() {
    disk raw "$@" -media cdrom
}

disk_autocreate() {
    local idx=0
    while [ $idx -lt $DASIZE ]; do
        local type=${DISK_ARGS[${idx},type]}
        "disk_${type}_create" $idx
        idx=$(( idx + 1 ))
    done
}

disk_autodelete() {
    local idx=0
    while [ $idx -lt $DASIZE ]; do
        local type=${DISK_ARGS[${idx},type]}
        # not all types need a custom delete, so the fn might not exist
        if [ "$(command -v "disk_$1_delete")x" != "x" ]; then
            "disk_${type}_delete" $idx 
        fi
        idx=$(( idx + 1 ))
    done
}

disk_raw_create() {
    local idx="$1"
    local name="${DISK_ARGS[$idx,name]}"
    local size="${DISK_ARGS[$idx,size]}"
    local url="${DISK_ARGS[$idx,url]}"
    local path="${DISK_ARGS[$idx,path]}"
    local if="${DISK_ARGS[$idx,if]}"
    local media="${DISK_ARGS[$idx,media]}"
    local ex="${DISK_ARGS[$idx,ex]}"

     # Create new image file
    if [ -n "$size" ]; then
        if [ -z "$name" ]; then
            fatal "size ($size) specified, but no name. can not create nameless disk."
        fi
        if [ -n "$path" ]; then
            fatal "path specified ($path) but -size implies creating a new file, refusing to overwrite."
        fi
        path="${DATADIR}/vm.${name}.img"
        if ! [ -f "$path" ]; then
            truncate -s "$size" "$path" || fatal "could not create empty image file (via truncate -s)"
        fi
    else
        if [ -n "$url" ]; then
            if [ -n "$path" ]; then
                fatal "path specified with -iso, which automatically determines it's own path."
            fi
            path=$(image_get "$url")
        else
            if [ -z "$path" ] || ! [ -r "$path" ]; then
                fatal "no image path was specified or path inaccessible: $path"
            fi  
        fi
    fi
    new_args="file=$path,format=raw"
    if [ -n "$media" ]; then
        new_args="${new_args},media=$media"
    fi
    if [ -n "$if" ]; then
        new_args="${new_args},if=$if"
    fi
    if [ -n "$ex" ]; then
        new_args="${new_args},$ex"
    fi
    QEMU_DISK_ARGS="${QEMU_DISK_ARGS} -drive ${new_args}"
}

disk_qcow_create() {
    local idx="$1"
    local name="${DISK_ARGS[$idx,name]}"
    local size="${DISK_ARGS[$idx,size]}"
    local if="${DISK_ARGS[$idx,if]}"
    local media="${DISK_ARGS[$idx,media]}"
    local ex="${DISK_ARGS[$idx,ex]}"    
    # Create new image file
    if [ -z "$size" ]; then
        fatal "no size specified for qcow disk image"
    fi
    if [ -z "$name" ]; then
        fatal "no name specified. can not create nameless disk."
    fi
    local path="${DATADIR}/vm.${name}.qcow"
    if ! [ -f "$path" ]; then
        qemu-img create -f qcow2 "$path" "$size" || fatal "could not create empty image file (via qcow)"
    fi
    newargs="file=$path,format=qcow"
    if [ -n "$media" ]; then
        new_args="${new_args},media=$media"
    fi
    if [ -n "$if" ]; then
        new_args="${new_args},if=$if"
    fi
    if [ -n "$ex" ]; then
        new_args="${new_args},$ex"
    fi
    QEMU_DISK_ARGS="${QEMU_DISK_ARGS} -drive ${new_args}"
}

disk_validate_type() {
    if [ "$(command -v "disk_$1")x" == "x" ] && [ "$(command -v "disk_$1_create")x" == "x" ]; then
        fatal "disk: type not found: $1"
    fi  
    echo "$1"
}

disk_validate_name() {
    if (echo "$1" | grep -vP '^\w+$' >/dev/null 2>&1); then
        fatal "not a valid name for a disk: $1"
    fi
    echo $1
}

disk_validate_size() {
    if (echo "$1" | grep -vP '^\d+[kKmMgGtT]$' >/dev/null 2>&1); then
        fatal "not a valid size for a disk: $1"
    fi
    echo $1
}

disk_validate_media() {
    if (echo "$1" | grep -P '^cdrom$' >/dev/null 2>&1); then
        echo "cdrom"
    else
        fatal "only -media cdrom is supported atm"
    fi
}

disk_validate_url() {
    # bad stackoverflow regex is bad... just be careful with this value
    regex='(https?|ftp|file)://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]'
    if (echo "$1" | grep -P "$regex" >/dev/null 2>&1); then
        echo "$1"
    else
        fatal "not a valid url: $1"
    fi
}

disk_validate_path() {
    if ! [ -r "$1" ]; then
        fatal "path is not accessible: $1"
    fi
    echo "$1"
}

# Download an image from the given url using a cache, returning the path to the cached image. 
image_get() {
    local url="$1"
    local url_id=$(echo "$url" | md5sum | cut -d' ' -f1)
    local filename="$ISO_CACHE_DIR/${url_id}.img"

    if ! mkdir -p "$ISO_CACHE_DIR"; then
        fatal "Failed to create ISO_CACHE_DIR, do you need root privilieges?"
    fi

    # download and cache url if not there already
    if ! [ -f "$filename" ]; then
        curl -o "$filename" "$url"
        local size=$(stat --format=%s "$filename" 2>/dev/null)
        if [ "$?" -ne 0 ] || [ "$size" == 0 ] ; then
            fatal "Failed to download $url"
        fi
        if [ "$size" -le 1048576 ]; then
            echo "warning: downloaded image is very small ($size bytes). contents of file are suspect. "
        fi
        echo "$url_id == $url" >> $ISO_CACHE_DIR/db.idx
    fi
    echo "$filename"
}

# Global 