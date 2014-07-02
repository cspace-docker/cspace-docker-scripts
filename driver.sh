#!/usr/bin/env bash
#
# Simple driver script to install a CollectionSpace server
# within a Docker container, by executing multiple Dockerfiles
# in sequence.
#
# This script is specific to and requires Ubuntu Linux,
# although most of its instructions should likely work with
# any recent Debian-based Linux distribution.

# Uncomment for verbose debugging
set -x

# ###############################################################
# Ensure that we have the latest version of Docker installed
# See http://docs.docker.com/installation/ubuntulinux/
# ###############################################################

# TODO: Check for the presence of a Docker executable matching
# or exceeding a minimum required version, and skip the following
# steps if it is present.

#
# If HTTPS transport hasn't yet been enabled for
# 'apt-get', enable that transport method.
#
[ -e /usr/lib/apt/methods/https ] || {
  apt-get update
  apt-get install apt-transport-https
}

#
# The following command can be run multiple times; if the relevant
# key is already present, that key will be unchanged.
#
# TODO: Check for the presence of a docker.io key via 'apt-key finger'
# or 'apt-key list' and don't redundantly run this command, if the
# key is already present. This will save time and network connections.
#
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 36A1D7869245C8950F966E92D8576A8BA88D21E9

#
# Run a script provided by Docker to install its APT repository
# configuration on Ubuntu systems.
#
# TODO: Check for the presence of this repository configuration and
# don't redundantly run this command, if the repo config is present.
#
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
# so that each successive image can be built on top of ("layered on")
# a previous one, via the 'FROM imagename' directive found in each Dockerfile.
#
# The '--rm=true' option removes intermediate images created as a result
# of each successful build, leaving only the last image successfully built.
# This helps prevent "image clutter."

#
# Build the first two images, in succession.
#
sudo $DOCKER_CMD build --rm=true --tag=collectionspace/cspace-base ./cspace-base               
sudo $DOCKER_CMD build --rm=true --tag=collectionspace/cspace-version ./cspace-provision-version  

#
# Read values from a per-instance configuration file and substitute
# those values for placeholder macros within a template Dockerfile, thus
# generating a Dockerfile specific to a particular instance of CollectionSpace.
#
# This Dockerfile will be used to build the third and last image, below.
#
sed -f ./cspace-provision-instance/cspace-instance-values.sed \
  ./cspace-provision-instance/Dockerfile.template > ./cspace-provision-instance/Dockerfile

#
# Build the third image.
#
sudo $DOCKER_CMD build --rm=true --tag=collectionspace/cspace-instance ./cspace-provision-instance
