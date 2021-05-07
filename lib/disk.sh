#!/bin/bash

# Syntax sugar for disk creation
disk() {
    local disktype="$1"
    shift
    # posix sh compliant way to check for a function
    if [ "$(command -v "disk_$disktype")x" != "x" ]; then
        "disk_$disktype" "$@"
    else
        echo "disk: type not found: $disktype"
        exit 1
    fi  
}

# Syntax sugar for setting media=cdrom
cdrom() {
    disk "$@" "cdrom"
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
        echo "disk"
    fi
}

# Attach a virtio definition
disk_virtio_new() {
    local name=$(disk_validate_name $1)
    local size=$(disk_validate_size $2)
    local media="$(disk_validate_media $3)"
    local idx=$DISK_N_DISKS
    eval "DISK${idx}_NAME=${name}"
    eval "DISK${idx}_SIZE=${size}"
    eval "DISK${idx}_PATH="
    eval "DISK${idx}_MEDIA=${media}"
    eval "DISK${idx}_TYPE=virtio"
    DISK_N_DISKS=$(( DISK_N_DISKS + 1 ))
}

# Attach a virtio definition
disk_virtio_file() {
    local path="$1" # TODO: SECURITY: Filter special chars
    local media="$(disk_validate_media $2)"
    local idx=$DISK_N_DISKS
    eval "DISK${idx}_PATH=${path}"
    eval "DISK${idx}_NAME="
    eval "DISK${idx}_SIZE="
    eval "DISK${idx}_MEDIA=${media}"
    eval "DISK${idx}_TYPE=virtio"
    DISK_N_DISKS=$(( DISK_N_DISKS + 1 ))
}

# Create virtio disk as needed and configure QEMU args
disk_virtio_autocreate() {
    local name="$1"
    local size="$2"
	local file="$3"
	local media="$4"

    if ( echo "$file" | grep -P '^(https?|ftp)://' >/dev/null 2>&1); then
        local path=$(image_get "$file")
    else
    	local path="$DATADIR/${VMNAME}.${name}.raw.img"
        if ! [ -f "$path" ]; then
            if [ -n "$name" ] && [ -n "$size" ]; then 
                truncate -s "$size" "$path"
            else
                fatal "virtio_autocreate: file not found: $path"
            fi
        fi
    fi

    # Add the disk to QEMU's DISK arglist
    if [ "$media" != "cdrom" ]; then
	    DISK_ARGS="${DISK_ARGS} -drive file=$path,if=virtio,format=raw,media=${media}"
    else
	    DISK_ARGS="${DISK_ARGS} -drive file=$path,media=${media}"
    fi
}

# Create System Disks - this is a simple flat file and installer ISO example
disk_autocreate() {
    local idx=0

    while [ "$idx" -lt "$DISK_N_DISKS" ]; do
        local name=$(eval echo "\$DISK${idx}_NAME")
        local size=$(eval echo "\$DISK${idx}_SIZE")
        local path=$(eval echo "\$DISK${idx}_PATH")
        local media=$(eval echo "\$DISK${idx}_MEDIA")
        local type=$(eval echo "\$DISK${idx}_TYPE")
        "disk_${type}_autocreate" "$name" "$size" "$path" "$media"
        idx=$(( idx + 1 ))
    done
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
DISK_N_DISKS=0
ISO_CACHE_DIR=/var/qemu/isos
