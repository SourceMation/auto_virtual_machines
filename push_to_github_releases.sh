#!/usr/bin/env bash

set -euo pipefail

BASE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROFILE=$1
. $BASE/$PROFILE

check_if_exit(){
    if [[ "$PUSH_TO_GITHUB" == "Y" ]]; then
        echo "Pushing to GitHub"
    else
        echo "Pushing to GitHub disabled"
        exit 0
    fi
}
check_if_exit

if [[ "$PACKER_BUILDER" =~  vmware* ]] || [[ "$PACKER_BUILDER" == "libvirt" ]] ;then
    export BOX_BASE_PATH="../workspace/packer-$BOX_NAME-$ARCH-$PACKER_BUILDER_SHORT"
else
    export BOX_BASE_PATH="../workspace/packer-$BOX_NAME-$ARCH-$PACKER_BUILDER"
fi
export GH_TAG="$BOX_BUILD"
export GH_RELEASE_BODY="This is $BOX_SHORT_DESC$APPSUFFIX built on $(date --iso-8601)"
export GH_RELEASE="$IMAGE-${BOXRELEASE}_$GH_TAG"
if [[ "$PACKER_BUILDER" == "libvirt" ]] ;then
    export ASSET_NAME="$BOX_NAME-$ARCH-$IMAGE.$PACKER_BUILDER_SHORT.qcow2"
    export ASSET_FILENAME="tested_$BOX_NAME-$ARCH-$IMAGE.$PACKER_BUILDER_SHORT.qcow2"
else
    export ASSET_NAME="$BOX_NAME-$ARCH-$IMAGE.$PACKER_BUILDER_SHORT.ova"
    export ASSET_FILENAME="tested_$BOX_NAME-$ARCH-$IMAGE.$PACKER_BUILDER_SHORT.ova"
fi
export SHASUM_BASE_PATH="packer"
export SHA512SUM="$BOX_NAME-$ARCH-$IMAGE.$PACKER_BUILDER_SHORT.sha512sum"


GH_API_TEMPL="gh_api_funct_template.sh"
GH_API_FUNCT="gh_api_funct.sh"

# create release

envsubst < $GH_API_TEMPL | tee $GH_API_FUNCT
. $GH_API_FUNCT

RELEASE_ID=$(create_release |jq '.id')

if [[ "$RELEASE_ID" =~ ^[0-9]+$ ]]; then
    echo "Release $RELEASE_ID created."
    export RELEASE_ID
elif [[ "$RELEASE_ID" == "null" ]]; then
    RELEASE_ID=$(get_release_by_tag |jq '.id')
    echo "Release $RELEASE_ID exists."
    export RELEASE_ID
else
    echo "Unknown response!"
    exit 1
fi

# push ova

envsubst < $GH_API_TEMPL | tee $GH_API_FUNCT
. $GH_API_FUNCT

ASSET_STATE=$(upload_release_asset |jq '.state'|xargs)

if [[ "$ASSET_STATE" == "uploaded" ]]; then
    echo "Image uploaded successfully!"
else
    echo "Something went worng!"
    exit 1
fi

# push sha512sum

export BOX_BASE_PATH="$SHASUM_BASE_PATH"
export ASSET_NAME="$SHA512SUM"
export ASSET_FILENAME="$SHA512SUM"

envsubst < $GH_API_TEMPL | tee $GH_API_FUNCT
. $GH_API_FUNCT

ASSET_STATE=$(upload_release_asset |jq '.state'|xargs)

if [[ "$ASSET_STATE" == "uploaded" ]]; then
    echo "Checksum uploaded successfully!"
else
    echo "Something went worng!"
    exit 1
fi
