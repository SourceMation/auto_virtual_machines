#!/bin/bash

case "$PACKER_BUILDER_TYPE" in

virtualbox-iso|virtualbox-ovf)
    dnf install -y kernel-headers kernel-modules
    mkdir /tmp/vbox
    VER=$(cat /root/.vbox_version)
    mount -o loop /root/VBoxGuestAdditions_$VER.iso /tmp/vbox
    sh /tmp/vbox/VBoxLinuxAdditions.run
    umount /tmp/vbox
    rmdir /tmp/vbox
    rm /root/*.iso
    ;;

vmware-iso|vmware-vmx)
    dnf install -y open-vm-tools
    VER=$(vmtoolsd -v|awk '{print $5}')
    echo "VMware Tools v$VER installed."
    systemctl enable vmtoolsd && echo "VMware Tools enabled."
    ;;

qemu)
    echo "Nothing to do here."
    ;;
*)
    echo "Unknown Packer Builder Type >>$PACKER_BUILDER_TYPE<< selected."
    echo "Known types are virtualbox-iso|virtualbox-ovf|vmware-iso|vmware-vmx|parallels-iso|parallels-pvm|qemu."
    ;;

esac
