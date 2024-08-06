#!/usr/bin/env bash

set -euo pipefail
BASE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROFILE=$1
STAGE=$2

if [ $STAGE -eq 1 ]; then
    # Build VMI
    bash -x make-basebox.sh $PROFILE
elif [ $STAGE -eq 2 ]; then
    # Test VMI
    . $BASE/$PROFILE
    export ARCH APPSUFFIX BOX_NAME BOXRELEASE IMAGE PACKER_BUILDER_SHORT

    case "$IMAGE" in
    base)
        export IMAGE_FULL="el-release" ;;
    java)
        export IMAGE_FULL="$IMAGE"
        ;;
    mongodb)
        export IMAGE_FULL="mongodb-enterprise"
        export BOXRELEASE="${BOXRELEASE}.*"
        ;;
    postgresql)
        export IMAGE_FULL="postgresql-server"
        export BOXRELEASE="${BOXRELEASE}.*"
        ;;
    python)
        export IMAGE_FULL="$IMAGE$(echo $BOXRELEASE|grep -oE ^[0-9])"
        export BOXRELEASE="${BOXRELEASE}.*"
        ;;
    rabbitmq)
        export IMAGE_FULL="rabbitmq-server"
        export BOXRELEASE="${BOXRELEASE}.*"
        ;;
    *)  export IMAGE_FULL="$IMAGE"
        export BOXRELEASE="${BOXRELEASE}.*"
        ;;
    esac

    bash -x smoke_test_${PACKER_BUILDER_SHORT}.sh

elif [ $STAGE -eq 3 ]; then
    # Push VMI to GitHub
    bash -x push_to_github_releases.sh $PROFILE
fi
