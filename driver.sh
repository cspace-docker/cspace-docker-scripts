#!/usr/bin/env bash
#
# Simple driver script to install a CollectionSpace server
# within a Docker container, by executing multiple Dockerfiles
# in sequence.

# Find the docker executable and get its path
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

# Execute multiple Dockerfiles in sequence.
#
# Each Docker image is given a pre-defined name (via the '--tag' option)
# so that each successive image can be built on top of the previous one,
# via a 'FROM imagename' directive in each Dockerfile.
#
# The '--rm=true' option removes intermediate images created during
# the run, if the build succeeds, leaving only the final image, to help
# prevent "image clutter."

sudo $DOCKER_CMD build --rm=true --tag=rem/cspace-base ./cspace-base               
sudo $DOCKER_CMD build --rm=true --tag=rem/cspace-version ./cspace-provision-version  

# Copy the template which holds default values
# to create a per-instance configuration file
cp ./cspace-provision-instance/cspace-instance.copyme ./cspace-provision-instance/cspace-instance.properties

# (Edit values in that configuration file, either manually
# or via automation)

# Build the last Docker image ("cspace-provision-instance"), in part,
# by referencing per-instance values stored in that configuration file

sudo $DOCKER_CMD build \
  --rm=true \
  --tag=rem/cspace-instance \
  --env-file=./cspace-instance.properties \
  ./cspace-provision-instance
