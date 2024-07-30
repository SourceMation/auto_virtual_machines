#!/bin/bash

echo "Removing unnecessary packages..."
dnf remove -y \
    linux-firmware \
    ethtool \
    --skip-broken

echo "Removing old kernels..."
dnf -y remove --oldinstallonly --setopt installonly_limit=2 kernel || echo "No old kernels found for removal."
dnf clean all
rm -rf /var/cache/yum
