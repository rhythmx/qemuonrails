If you've used QEMU for much, you've created more shell scripts than you wanted to in order to manage it.

These tools attempt to be generic enough that you can make some small edits to these example templates and instantly have tools suitable enough to create auto-booting production VMs. But at the same time, the simple nature of these scripts doesn't get in the way of all the fancy QEMU developer sauce you don't get with "real" virtual machine managers.

# Getting Started

Dependencies: 
  * `GNU screen`
  * `libreadline` (for rlwrap)
  * `socat` 

More involved examples might require other tools. 

## Standalone

The `demo.sh` example downloads an Arch Linux installation cd and boots it with basic disk and networking.

Just run `sudo ./demo.sh create` like so:

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

## Systemd

Place `qemu@.service` into `/etc/systemd/system`.

Choose a file from the examples (demo.sh) and place it in `/etc/qemu/` (make sure it is marked executable)

Now run the following: 
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

This can create disks, download images, or configure any other persistent resources the VM might need.

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

Also, by default, QEMU runs inside its own screen session. If you want access to the serial console of your vm, just run `screen -DR demo`. Here you can see the bios, and if your OS has a serial console enable, you can interact with that.

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

To customize your vm, just copy one of the examples to `yourvm.sh`. Have a look at the `disk_setup` and `disk_cleanup` functions and edit those to modify the storage. To modify the networking, look at the `if_setup` and `if_cleanup` functions. Lastly, if you want to directly modify qemu arguments, edit the `launch_qemu` function.
