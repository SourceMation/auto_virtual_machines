#!/usr/bin/env bash

[ -e /etc/hosts.back ] && mv -v /etc/hosts.back /etc/hosts

# rebuild rpm database - it makes it smaller
rpmdb --rebuilddb

# Whipeout the swap partition to reduce box size
# Swap is disabled till reboot
readonly swapuuid=$(/sbin/blkid -o value -l -s UUID -t TYPE=swap)
readonly swappart=$(readlink -f /dev/disk/by-uuid/"$swapuuid")
/sbin/swapoff "$swappart"
dd if=/dev/zero of="$swappart" bs=1M || echo "dd exit code $? is suppressed"
/sbin/mkswap -U "$swapuuid" "$swappart"


echo "Make /EMPTY"
dd if=/dev/zero of=/EMPTY bs=512K
rm -f /EMPTY
echo "Make /boot/EMPTY"
dd if=/dev/zero of=/boot/EMPTY bs=512K
rm -f /boot/EMPTY

sync
