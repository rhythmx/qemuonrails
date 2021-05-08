# QEMU-on-Rails

If you've used QEMU for much, you've created more shell scripts than you've
wanted to in order to manage it all.

These tools provide a simple and reusable framework for a scriptable VM server.

They attempt to be generic enough that you can make some small edits to these
example templates and instantly have tools suitable enough to create
auto-booting production VMs. At the same time, the simple nature of these
scripts doesn't get in the way of all the fancy QEMU developer sauce you don't
get with "real" virtual machine managers.

## Demos/Examples

* `alpine-aarch64` - AArch64 softcpu emulator running the Alpine Linux live cd
* `alpine-i386` - i386 softcpu emulator running the Alpine Linux live cd (you probably want x86 on x86_64+kvm though)
* `alpine-ppc64` - PPC64 softcpu emulator running the Alpine Linux live cd
* `alpine-x86_64` - x86_64/x86 (KVM Hypervisor) running the Alpine Linux live cd
* `hugepages` - Quick example of using hugetlbfs for optimized guest memory 
* `lvmraid_vlanbridge` - More involved example showing an optimized LVM setup and the use of VLANFiltering with Linux bridging
* `win10` - Windows 10 VM with some Hyper-V tuning

# Getting Started

Dependencies: 
  * `GNU screen` 
  * `socat`, `libreadline` (for `monitor` command) 

More involved features might require other tools. 

## Standalone

The `demo.sh` example downloads a Linux installation cd and boots it with basic disk and networking.

Just run the `start` command like so, it'll format the disk and download the installer automatically:

```
[sean@kor] $ sudo ./demo.sh start
10240+0 records in
10240+0 records out
41943040 bytes (42 MB, 40 MiB) copied, 0.0400444 s, 1.0 GB/s
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100  755M  100  755M    0     0  6988k      0  0:01:50  0:01:50 --:--:-- 10.0M
```

```
[sean@kor] $ sudo ./demo.sh status
VM status: running
```

## Controlling via Systemd

Just run `install.sh`.

The installer places `qemu@.service` into `/etc/systemd/system` and places the example `vm.sh` files into `/etc/qemu`. 

Now run you can run systemd commands like the following to manage your vms: 
```
systemctl enable --now qemu@demo
```

```
[root@vm ~]# systemctl status qemu@demo
● qemu@demo.service - QEMU virtual machine
     Loaded: loaded (/etc/systemd/system/qemu@.service; enabled; vendor preset: disabled)
     Active: active (running) since Sun 2021-05-02 01:48:03 CDT; 5s ago
    Process: 35368 ExecStart=/etc/qemu/demo.sh start (code=exited, status=0/SUCCESS)
   Main PID: 35221 (qemu-system-x86)
      Tasks: 0 (limit: 76892)
     Memory: 4.0K
        CPU: 64ms
     CGroup: /system.slice/system-qemu.slice/qemu@demo.service
             ‣ 35221 qemu-system-x86_64 -pidfile /run/qemu/demo/demo.pid -name demo -cpu host --enable-kvm -m 2G -nographic ->

May 02 01:48:03 vm systemd[1]: Starting QEMU virtual machine...
May 02 01:48:03 vm demo.sh[35368]: this vm is already running!
May 02 01:48:03 vm systemd[1]: qemu@demo.service: Supervising process 35221 which is not our child. We'll most likely not not>
May 02 01:48:03 vm systemd[1]: Started QEMU virtual machine.
```

This will create and start the demo VM, and enable it to start on every boot.

To disable it, run `systemctl disable -now qemu@demo`

To delete the resources from disk, run `/etc/qemu/demo.sh delete`

# Other features

## Automatic Creation ##

This can create disks, download ISO or disk images, or configure any other persistent resources the VM might need.

```
[root@vm systemd-qemu]# ./demo.sh create
  Logical volume "vm.demo.root" created.
  Logical volume "vm.demo.root.cache" created.
  Logical volume vg0/vm.demo.root is now cached.
  Logical volume "vm.demo.swap" created.
```

## Runtime Management ##

With the `command` option you can send one-liner commands to QEMU like so:

```
[root@vm ~]# /etc/qemu/demo.sh command info network
virtio-net-pci.0: index=0,type=nic,model=virtio-net-pci,macaddr=52:54:00:12:34:56
 \ n1: index=0,type=tap,ifname=demo0,script=no,downscript=no
```

```
[root@vm ~]# /etc/qemu/demo.sh command info registers
RAX=ffffffff9eadb380 RBX=0000000000000000 RCX=0000000000000001 RDX=000000000005ac02
RSI=0000000000000087 RDI=0000000000000000 RBP=ffffffff9f603e38 RSP=ffffffff9f603e18
R8 =ffff8ba638a1e4a0 R9 =0000000000000200 R10=0000000000000000 R11=0000000000000000
R12=0000000000000000 R13=ffffffff9f613780 R14=0000000000000000 R15=0000000000000000
RIP=ffffffff9eadb76e RFL=00000246 [---Z-P-] CPL=0 II=0 A20=1 SMM=0 HLT=1
...
```

Or, you can use the `monitor` option to run commands interactively within a readline shell.

Swapping the cdrom:
```
[root@vm ~]# /etc/qemu/demo.sh monitor
QEMU 5.2.0 monitor - type 'help' for more information
(qemu) eject -f ide1-cd0
eject -f ide1-cd0
(qemu) change ide1-cd0 /isos/ubuntu-20.04.iso
change ide1-cd0 /isos/ubuntu-20.04.iso
```

Enable VNC access:
```
[root@vm ~]# /etc/qemu/demo.sh monitor
QEMU 5.2.0 monitor - type 'help' for more information
(qemu) change vnc 127.0.0.1:0
change vnc 127.0.0.1:0
(qemu) change vnc password
change vnc password
Password: hunter2
```

Also, by default, QEMU runs inside its own screen session. If you want access to the serial console of your vm, just run `screen -DR demo`. Here you can see the bios, and if your OS has a serial console enabled, you can interact with that too.

## Other features

```
Usage: vmname.sh (start | run | wait | status | create | command | monitor | shutdown | reboot | delete)
Management util for creating/launching/monitoring a QEMU virtual machine

Commands:
  start:    run this virtual machine and return
  run:      run this virtual machine and wait until it powers off
  wait:     wait until the VM powers off and then cleanup
  status:   show the VMs current run status
  create:   create new virtual disks and anyh other one-time setup
  command:  run a monitor command (like 'info vnc' or 'device add ...')
  monitor:  start a monitor shell (^D to exit, 'quit' will terminate the VM)
  shutdown: shutdown the VM gracefully (like short-pressing the power button)
  reboot:   reset the VM
  delete:   delete the disks and any other persistent resources
```

# Customization

There are 3 main ways to go about customizing a VM script.

1) Adding/removing setup macros in the VM script
2) Defining "hook" functions 
3) Implementing "site" libraries  


## Setup and configuration macros

The first line in any VM script should include the main `qemuonrails.sh` library like so: 

```shell
. $(dirname $0)/lib/qemuonrails.sh
```

Similarly, the last line in the vmscript should always be:

```shell
command_handler "$@"
```

Most scripts will want to include some common functionality:

```shell
include platforms
include disk
include network
```

### Platforms

The plaforms library contains a collection of common settings for various hardware and software combinations. These will usually pre-define which CPU and Machine type to use, if KVM should be enabled, SMP, common peripherals, etc.

It also exposes a few helper functions to override the defaults, like so:

```shell
memory     4G
processors 2
```

### Disk

The disk library will auto-provision new disk images for you when your VM is
created and clean them up when it is deleted. It has support for flat file
images, qcow2 images, and it can also download and cache images from a given
URL.

Examples:
```shell
disk  raw -name "rootfs" -size 10G -if virtio
disk  qcow -name "c-drive" -size 64G -if virtio
cdrom -url "https://dl-cdn.alpinelinux.org/alpine/v3.13/releases/x86_64/alpine-standard-3.13.5-x86_64.iso"
cdrom -path "/home/sean/Windows10.iso"
```

### Network

At present, the only one default networking mode is supported: usermode networking. This is because the most common other modes require pre-existing system configuration, like bridging to be up and ready. There is an example "site" library for dealing with this, but it is always going to be rather specific to the individual host.

```shell
network virtio_user
```

## Custom "hooks"

To further customize the virtual machine environment, you can define one of
a few main shell functions that allow you to inject arguments at various points
in the vm creation and startup process. 

* `data_create`: this function is called when the vm data is created for the first time.
* `data_delete`: called when deleting all persistent vm resources
* `network_create`: called when turning on the vm to provision network resources
* `network_delete`: called after the vm has stopped running
* `qemu_launch`: called just before QEMU lauches, giving a last chance to alter the QEMU arguments 

## Site libraries

These libraries allow you to create new macros specific to your local setup. The
examples included add new disk types that support LVM raid and cacheing features
as well as new networking types that support bridged tap adapters with hidden
vlan tagging. 
