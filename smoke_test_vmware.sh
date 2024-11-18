#!/usr/bin/env bash

set -euo pipefail
BASE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd ../workspace/packer-$BOX_NAME-$ARCH-vmware/
VM="$BOX_NAME-$ARCH-$IMAGE.$PACKER_BUILDER_SHORT"
mkdir -p test


vmware_destroy() {
    echo "Stopping VM..."
    vmrun stop test/$VM.vmx soft || echo "Failed to read from file: $VM.vmx"
    echo "Removing VM..."
    vmrun deleteVM test/$VM.vmx || echo "Failed to read from file: $VM.vmx"
    vmrun list
}

trap vmware_destroy EXIT ERR 1 2 3 4 5 6

vmware_convert() {
    echo "Converting to VMX"
    ovftool $VM.ova test/$VM.vmx
}

vmware_run() {
    vmrun -T ws -gu root -gp sourcemation start test/$VM.vmx nogui
}

vmware_check_tools() {
    vmrun checkToolsState test/$VM.vmx
}

vmware_get_ip() {
    IP=$(vmrun getGuestIPAddress test/$VM.vmx -wait)
    echo $IP
    export IP
}

vmware_add_ssh_key() {
    export SSHOPTS='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'

    ssh-keygen -t ed25519 -f ssh_smoketest_key -C "smoketest@vboxbuilder" -N ''
    SMOKETESTKEY_PUB=$(cat ssh_smoketest_key.pub)

    sshpass -p sourcemation \
    ssh $SSHOPTS \
    root@$IP \
    /bin/echo \
    "$SMOKETESTKEY_PUB >> /root/.ssh/authorized_keys"
}

vmware_test() {
    SSHOPTS="$SSHOPTS -i ssh_smoketest_key"

    echo "Smoke test 1: Is system able to read its own release?"
    ssh $SSHOPTS root@$IP cat /etc/os-release >/dev/null 2>&1
    echo "Yes, it is."

    echo "Smoke test 2: Does system has a uname?"
    ssh $SSHOPTS root@$IP uname -a >/dev/null 2>&1
    echo "Yes, it does."

    echo "Smoke test 3: Can it read https://www.google.com/?"
    ssh $SSHOPTS root@$IP curl -k https://www.google.com/ >/dev/null 2>&1
    echo "Yes, it can."

    echo "Smoke test 4: How about using repolist?"
    ssh $SSHOPTS root@$IP 'dnf clean all; dnf repolist' >/dev/null 2>&1
    echo "Yay, it's working!"

    echo "Smoke test 5(final): Get info from local rpm db about $IMAGE."
    ssh $SSHOPTS root@$IP "rpm -qi $IMAGE_FULL-$BOXRELEASE$APPSUFFIX"
    echo "Everything seems to be fine!"
    echo "Let's end this stage."
}

vmware_copy() {
    echo "Mark image as tested."
    mv $VM.ova tested_$VM.ova
}


vmware_convert
vmware_run
vmware_check_tools
vmware_get_ip
vmware_add_ssh_key
vmware_test
vmware_copy
