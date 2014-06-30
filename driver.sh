#!/usr/bin/env bash
#
# Simple driver script to install a CollectionSpace server
# within a Docker container, by executing multiple Dockerfiles
# in sequence.

# Uncomment for verbose debugging
set -x

# ###############################################################
# Ensure that we have the latest version of Docker installed
# See http://docs.docker.com/installation/ubuntulinux/
# ###############################################################

[ -e /usr/lib/apt/methods/https ] || {
  apt-get update
  apt-get install apt-transport-https
}

# The following command can be run multiple times; if the relevant
# key is present, it will be unchanged.
#
# TODO: Check for the presence of a docker.io key via 'apt-key finger'
# or 'apt-key list' and don't redundantly run this command, if the
# key is already present. This will save time and network connections.
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 36A1D7869245C8950F966E92D8576A8BA88D21E9

curl -s https://get.docker.io/ubuntu/ | sudo sh

# ###############################################################
# Find the docker executable and get its path
# ###############################################################

# TODO: Consider using 'type -P' rather than 'command -v' here; see
# http://www.cyberciti.biz/faq/unix-linux-shell-find-out-posixcommand-exists-or-not/

DOCKER_CMD=`command -v docker`
if [ -z "$DOCKER_CMD" ]
  then
    # Name of docker command as currently installed in Ubuntu 14.04
    # See http://blog.docker.com/2014/04/docker-in-ubuntu-ubuntu-in-docker/#comment-1146
    DOCKER_CMD=`command -v docker.io`
fi
if [ -z "$DOCKER_CMD" ]
  then 
    echo "Error: Could not find docker command; exiting ..."
    exit 1
fi
echo "Found docker command at $DOCKER_CMD"

# ###############################################################
# Execute multiple Dockerfiles in sequence
# ###############################################################

# Each Docker image is given a pre-defined name (via the '--tag' option)
# so that each successive image can be built on top of the previous one,
# via a 'FROM imagename' directive in each Dockerfile.
#
# The '--rm=true' option removes intermediate images created during
# the run, if the build succeeds, leaving only the final image, to help
# prevent "image clutter."

sudo $DOCKER_CMD build --rm=true --tag=collectionspace/cspace-base ./cspace-base               
sudo $DOCKER_CMD build --rm=true --tag=collectionspace/cspace-version ./cspace-provision-version  

# Check for a script that sets a variety of environment variables needed
# to build a CollectionSpace instance. 
#
# If that script file doesn't exist, use default values:
# Copy the template which holds default values to create that script.
# FIXME: Store multiply-reused paths and filenames in variables here.
if [ ! -f ./cspace-provision-instance/cspace-instance.sh ]; then
  cp ./cspace-provision-instance/cspace-instance.copyme ./cspace-provision-instance/cspace-instance.sh
fi

# Run the environment variable setup script
chmod u+x ./cspace-provision-instance/cspace-instance.sh
source ./cspace-provision-instance/cspace-instance.sh

# Display these values (for debugging)
env

# Build the last Docker image ("cspace-provision-instance"), in part,
# by referencing per-instance values stored in that configuration file

# FIXME: Uncomment the following and pass in selected environment variables.

# sudo $DOCKER_CMD build \
#   --rm=true \
#   --tag=collectionspace/cspace-instance \
#   ./cspace-provision-instance
