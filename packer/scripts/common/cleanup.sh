#!/bin/bash -eux

dnf -y clean all
rm -rf VBoxGuestAdditions_*.iso VBoxGuestAdditions_*.iso.?
rm -rf /var/cache/yum
rm -rf /var/cache/dnf
find /var/log -type f -delete
