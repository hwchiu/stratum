#!/usr/bin/env bash
#
# Copyright 2018-present Open Networking Foundation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

if [[ $EUID -eq 0 ]]; then
   echo "This script should not be run as root, run it as the user who owns the Stratum source directory"
   exit 1
fi

PULL_DOCKER=NO
MOUNT_SSH=NO
BAZEL_CACHE=$HOME/.cache

print_help() {
cat << EOF
Builds a docker image using Dockerfile.dev and runs a bash session in it. It is
a convenient environment to do Stratum development. The docker image includes
the Bazel build system, git and popular Linux text editors. This Stratum source
directory will be mounted in the docker image. A local cache directory can be
provided to the running docker image so that restarting the docker does not
trigger a complete rebuild of Stratum. The host ssh keys can also be mounted in
the docker to facilitate git usage. The docker image will take some time to
build the first time this script is run.

Usage: $0
    [--pull]                        pull the latest debian base image
    [--mount-ssh]                   mount the HOME/.ssh directory into the docker image
    [--bazel-cache <path>]          mount the provided directory into the docker image and use it as the Bazel cache;
                                    default is HOME/.cache
    [--git-name <name>]             use the provided name for git commits
    [--git-email <email>]           use the provided email for git commits
    [--git-editor <editor command>] use the provided editor for git
    [-- [Docker options]]           additional Docker options for running the container
EOF
}

while [[ $# -gt 0 ]]
do
    key="$1"
    case $key in
        -h|--help)
        print_help
        exit 0
        ;;
    --pull)
        PULL_DOCKER=YES
        shift
        ;;
    --mount-ssh)
        MOUNT_SSH=YES
        shift
        ;;
    --bazel-cache)
        BAZEL_CACHE="$2"
        shift
        shift
        ;;
    --git-name)
        GIT_NAME="$2"
        shift
        shift
        ;;
    --git-email)
        GIT_EMAIL="$2"
        shift
        shift
        ;;
    --git-editor)
        GIT_EDITOR="$2"
        shift
        shift
        ;;
    "--")
        shift
        break
        ;;
    *)  # unknown option
        print_help
        exit 1
        ;;
    esac
done

THIS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
IMAGE_NAME=stratum-dev

DOCKER_BUILD_OPTIONS+=( "-t" "$IMAGE_NAME" "--build-arg" "USER_NAME=\"$USER\"" "--build-arg" "USER_ID=\"$UID\"" )

[ "$PULL_DOCKER" == YES ] && DOCKER_BUILD_OPTIONS+=( "--pull" )
[ -n "$GIT_NAME" ] && DOCKER_BUILD_OPTIONS+=( "--build-arg" "GIT_GLOBAL_NAME=\"$GIT_NAME\"" )
[ -n "$GIT_EMAIL" ] && DOCKER_BUILD_OPTIONS+=( "--build-arg" "GIT_GLOBAL_EMAIL=\"$GIT_EMAIL\"" )
[ -n "$GIT_EDITOR" ] && DOCKER_BUILD_OPTIONS+=( "--build-arg" "GIT_GLOBAL_EDITOR=\"$GIT_EDITOR\"" )

eval docker build "${DOCKER_BUILD_OPTIONS[@]}" -f "$THIS_DIR/Dockerfile.dev" "$THIS_DIR"
ERR=$?
if [ $ERR -ne 0 ]; then
    >&2 echo "ERROR: Error while building dockering development image"
    exit $ERR
fi

DOCKER_RUN_OPTIONS=( "--rm" "-v" "$THIS_DIR:/stratum" "-v" "$BAZEL_CACHE:/home/$USER/.cache" )

[ "$MOUNT_SSH" == YES ] &&  DOCKER_RUN_OPTIONS+=( "$HOME/.ssh:/home/$USER/.ssh" )
[ -n "$SDKLT" ] && DOCKER_RUN_OPTIONS+=( "-v" "$SDKLT:/home/$USER/SDKLT" ) &&  DOCKER_RUN_OPTIONS+=( "-e" "SDKLT_INSTALL=$SDKLT_INSTALL")

docker run "${DOCKER_RUN_OPTIONS[@]}" -w /stratum --user "$USER" -ti "$IMAGE_NAME" bash
