#!/usr/bin/env bash

set -euo pipefail
BASE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"


vbox_destroy() {
    vboxmanage controlvm $BOX_NAME-$IMAGE poweroff
    echo "Removing VM..."
    vboxmanage unregistervm --delete $BOX_NAME-$IMAGE
    rm -rf ../workspace/packer-$BOX_NAME-$ARCH-virtualbox/$BOX_NAME-$ARCH-$IMAGE.$PACKER_BUILDER_SHORT.ova
}

trap vbox_destroy EXIT ERR 1 2 3 4 5 6

vbox_import() {
    vboxmanage import \
    ../workspace/packer-$BOX_NAME-$ARCH-virtualbox/$BOX_NAME-$ARCH-$IMAGE.$PACKER_BUILDER_SHORT.ova \
    --vsys 0 \
    --vmname $BOX_NAME-$IMAGE

    vboxmanage modifyvm \
    $BOX_NAME-$IMAGE \
    --natpf1 "guestssh,tcp,,2222,,22"
}

vbox_start() {
    vboxmanage startvm \
    $BOX_NAME-$IMAGE \
    --type headless
    vboxmanage list runningvms |awk '{print $1}'|tr -d '"'
}

vbox_add_ssh_key() {
    export SSHOPTS='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p2222'

    ssh-keygen -t ed25519 -f ssh_smoketest_key -C "smoketest@vboxbuilder" -N ''
    SMOKETESTKEY_PUB=$(cat ssh_smoketest_key.pub)

    sshpass -p sourcemation \
    ssh $SSHOPTS \
    root@127.0.0.1 \
    /bin/echo \
    "$SMOKETESTKEY_PUB >> /root/.ssh/authorized_keys"
}

vbox_test() {
    SSHOPTS="$SSHOPTS -i ssh_smoketest_key"

    echo "Smoke test 1: Is system able to read its own release?"
    ssh $SSHOPTS root@127.0.0.1 cat /etc/os-release >/dev/null 2>&1
    echo "Yes, it is."

    echo "Smoke test 2: Does system has a uname?"
    ssh $SSHOPTS root@127.0.0.1 uname -a >/dev/null 2>&1
    echo "Yes, it does."

    echo "Smoke test 3: Can it read https://www.google.com/?"
    ssh $SSHOPTS root@127.0.0.1 curl -k https://www.google.com/ >/dev/null 2>&1
    echo "Yes, it can."

    echo "Smoke test 4: How about using repolist?"
    ssh $SSHOPTS root@127.0.0.1 'dnf clean all; dnf repolist' >/dev/null 2>&1
    echo "Yay, it's working!"

    echo "Smoke test 5(final): Get info from local rpm db about $IMAGE."
    ssh $SSHOPTS root@127.0.0.1 "rpm -qi rpm"
    echo "Everything seems to be fine!"
    echo "Let's end this stage."
}

vbox_copy() {
    echo "Mark image as tested."
    cd ../workspace/packer-$BOX_NAME-$ARCH-virtualbox/
    mv $BOX_NAME-$ARCH-$IMAGE.$PACKER_BUILDER_SHORT.ova tested_$BOX_NAME-$ARCH-$IMAGE.$PACKER_BUILDER_SHORT.ova
}

vbox_import
vbox_start
vbox_add_ssh_key
vbox_test
vbox_copy
