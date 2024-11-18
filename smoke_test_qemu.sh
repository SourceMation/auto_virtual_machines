#!/usr/bin/env bash

set -euo pipefail
BASE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"


qemu_destroy(){
    echo "Removing VM..."
    sudo virsh destroy el9-test
    rm -rf /tmp/$BOX_NAME.qcow2
    echo "Cleaning default pool..."
	for i in $(sudo virsh vol-list --pool default |grep "img" |awk '{print $1}' ); do
	    sudo virsh vol-delete --pool default $i
	done
}

trap qemu_destroy EXIT ERR 1 2 3 4 5 6

qemu_import() {
    cp ../workspace/packer-$BOX_NAME-$ARCH-qemu/$BOX_NAME-$ARCH-$IMAGE.$PACKER_BUILDER_SHORT.qcow2 /tmp/$BOX_NAME.qcow2
    sudo virsh create packer/templates/el9-qemu.xml
    sleep 30
    sudo virsh list --all|grep el9-test
}

qemu_get_ip() {
    IP=$(sudo virsh domifaddr el9-test |grep ipv4|awk '{print $4}' |sed 's/\/24//')
    echo $IP
    export IP
}

qemu_add_ssh_key() {
    export SSHOPTS='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'

    ssh-keygen -t ed25519 -f ssh_smoketest_key -C "smoketest@vboxbuilder" -N ''
    SMOKETESTKEY_PUB=$(cat ssh_smoketest_key.pub)

    sshpass -p sourcemation \
    ssh $SSHOPTS \
    root@$IP \
    /bin/echo \
    "$SMOKETESTKEY_PUB >> /root/.ssh/authorized_keys"
}

qemu_test() {
    SSHOPTS="$SSHOPTS -i ssh_smoketest_key"

    echo "Smoke test 1: Is system able to read its own release?"
    ssh $SSHOPTS root@$IP  cat /etc/os-release >/dev/null 2>&1
    echo "Yes, it is."

    echo "Smoke test 2: Does system has a uname?"
    ssh $SSHOPTS root@$IP  uname -a >/dev/null 2>&1
    echo "Yes, it does."

    echo "Smoke test 3: Can it read https://www.google.com/?"
    ssh $SSHOPTS root@$IP  curl -k https://www.google.com/ >/dev/null 2>&1
    echo "Yes, it can."

    echo "Smoke test 4: How about using repolist?"
    ssh $SSHOPTS root@$IP  'dnf clean all; dnf repolist' >/dev/null 2>&1
    echo "Yay, it's working!"

    echo "Smoke test 5(final): Get info from local rpm db about $IMAGE."
    ssh $SSHOPTS root@$IP  "rpm -qi rpm"
    echo "Everything seems to be fine!"
    echo "Let's end this stage."
}

qemu_copy() {
    echo "Mark image as tested."
    cd ../workspace/packer-$BOX_NAME-$ARCH-qemu/
    mv $BOX_NAME-$ARCH-$IMAGE.$PACKER_BUILDER_SHORT.qcow2 tested_$BOX_NAME-$ARCH-$IMAGE.$PACKER_BUILDER_SHORT.qcow2
}

qemu_import
qemu_get_ip
qemu_add_ssh_key
qemu_test
qemu_copy
