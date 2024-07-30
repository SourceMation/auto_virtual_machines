#!/bin/bash
MY_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
MY_NAME=${0##*/}
#EXTRA_PACKER_ARGS=" -debug "
#EXTRA_PACKER_ARGS="-on-error=ask"


print_usage(){
    echo "USAGE: $MY_NAME profile_name"
    echo "Example: $MY_NAME .profiles/el/images/el9-${IMAGE}.conf"
    echo "PROFILES:: are stored in $MY_DIR/profiles"
    exit 1
}

if [ $# -ne 1 ]; then
    print_usage
fi

profile=$1
profile_file=$MY_DIR/${profile}
shift

# parse config
if [ -f "$profile_file" ];then
    echo "Parsing profile config - ${profile_file}"
    . "${profile_file}"
else
    echo "Profile $profile not found - config file $profile_file does not exist"
    exit 1
fi


BASE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo "Setting packer environments"

export PACKER_CACHE=$MY_DIR/../workspace/packer_cache
export PACKER_CACHE_DIR=$PACKER_CACHE


if [ "$PACKER_BUILDER" = "virtualbox" ];then
    which vboxmanage &> /dev/null || { echo "Failed to find vboxmanage.. Install VirtualBox first" >&2;exit 1; }
    export VBOX_VERSION=$(vboxmanage -v|grep -oP '^\d+\.\d+\.\d+')
    echo "Detected VirtualBox version: $VBOX_VERSION"
fi

if [ "$PACKER_DEBUG" ];then
    echo "Enabling debug mode for packer"
    debug="-debug"
    export PACKER_LOG=true
fi

export IMAGE
export ISO_SERVER
export BOXPACKER=${BOXPACKER:-packer}
export ISO_NAME
export ISO_CHECKSUM
export BOX_NAME
export BOX_FULLNAME=${BOX_NAME}-${IMAGE}-${BOXRELEASE}
export BOXRELEASE
export BOX_DESC
export BOX_BUILD
export BOXOUTDIR=$BASE/../workspace/packer_builds/$PACKER_BUILDER/
export PACKER_BUILDER_SHORT

cat << EOF

Starting build of VM:
 - box packager=$BOXPACKER
 - template=$PACKER_TEMPLATE
 - ISO: ${ISO_SERVER}${ISO_NAME}, sha1sum=$ISO_CHECKSUM
 - builder=$PACKER_BUILDER:
    - box name: ${BOX_NAME}-${IMAGE}
    - box release: $BOXRELEASE
    - box description: $BOX_DESC
    - box build: $BOX_BUILD

EOF
packertmp=/var/tmp/packer
echo "Cleaning after old builds"
rm -fr $packertmp $BASE/../workspace/packer_builds $BASE/../workspace/packer-* $BASE/../packer-tmp

if [ "$PACKER_BUILDER" = "virtualbox" ]; then
    rm -rf ~/VirtualBox\ VMs/*
fi

# set tmp dir to not use default /tmp - https://github.com/mitchellh/packer/issues/1618
[ -d $packertmp ] || mkdir -p $packertmp

set -e

if [ $BOXPACKER = "packer" ];then
    for f in {/usr/local/bin,~/packerbin}/packer;do
        [ -x $f ] && { packerbin=$f; break; }
    done

    [ -n "$packerbin" ] || { echo "Could not find packer binary... please put packer in /usr/local/bin" >&2; exit 1; }

    cd "$BASE/packer/"

    # hcl2 have different names for providers. But these names are used in API
    # during push, so it's easier to fix that here than adding new vars to all profiles
    if [ "$PACKER_BUILDER" = "virtualbox" ]; then
        new_builder_name="virtualbox-iso.virtualbox"
    elif [ "$PACKER_BUILDER" = "vmware_workstation" ]; then
        new_builder_name="vmware-iso.vmware_workstation"
    elif [ "$PACKER_BUILDER" = "libvirt" ]; then
        new_builder_name="qemu.libvirt"
        # We need qemu-kvm from /usr/libexec
        export PATH=$PATH:/usr/libexec
    else
        echo "Sorry provider not recognized.... exiting ..."
        exit 1
    fi

    TMPDIR=$packertmp $packerbin build $EXTRA_PACKER_ARGS -only=$new_builder_name -var 'headless=true' -var "description=${BOX_DESC}" ${PACKER_TEMPLATE}.pkr.hcl

else
    echo "Unknown packager: $BOXPACKER"
    exit 1
fi
