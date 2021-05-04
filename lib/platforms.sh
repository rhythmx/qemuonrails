#!/bin/bash

# Helper function to set default environment variables for various platforms 
platform() {
    local platform="$1"
    shift
    # posix sh compliant way to check for a function
    if [ "$(command -v "platform_$platform")x" != "x" ]; then
        "platform_$platform" "$@"
    else
        echo "platform: not found: $platform"
    fi  
}

platform_defaults() {
    # Various Tunable Parameters
    QEMU_BIN="qemu-system-x86_64" # can change this to any arch, even non native (disable kvm though)
    QEMU_MEM="-m 2G,slots=2"
    QEMU_CPU="-smp cpus=1,cores=1,threads=1"
    QEMU_KVM="-enable-kvm -cpu host"
    QEMU_VID="-vga qxl"
    QEMU_VNC="-vnc none"
    QEMU_EXT=""
}

platform_native() {
    # take defaults
    return
}

platform_windows10() {
    QEMU_MEM="-m 8G"
    # See https://github.com/qemu/qemu/blob/master/docs/hyperv.txt
    QEMU_KVM="-enable-kvm -cpu host,hv_relaxed,hv_spinlocks=0x1fff,hv_vapic,hv_time" 
    QEMU_CPU="-smp cpus=4"
    QEMU_VID="-vga virtio"
    QEMU_EXT="-audiodev pa,id=snd0 -device ich9-intel-hda -device hda-output,audiodev=snd0" # untested
}

memory() {
    QEMU_MEM="-m $1"
}

processors() {
    QEMU_CPU="-smp $1"
}

# Initialize the globals here
platform_defaults