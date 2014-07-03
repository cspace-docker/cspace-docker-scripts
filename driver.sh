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
# set -x

# ###############################################################
# Utility functions
# ###############################################################

# Compare two 'dotted' version numbers (e.g. 1.9, 1.8.22, etc.)
# Returns the result in a global variable:
# version_equals_or_exceeds_check
# Returns 0 if supplied version is >= than checked-for version.
# Returns 1 if checked-for version is greater.
# Echoes versions, one per line, deleting blank lines, if any.
# Then sorts with '-t.', specifying that the dot character (.)
# is used as a field separator, and sorting respectively on the
# first four fields of the dotted version number, via 'nr', thus
# performing a reverse numeric sort, so that the highest version
# number appears on line 1 of the output.
#
# Based on aspects of this approach (as modified by reader comment):
# http://fitnr.com/bash-comparing-version-strings.html#comment-221464671
# and this one, as well:
# http://stackoverflow.com/a/4495368
check_version()
{
    echo "Checking version ..."
    local version_supplied=$1 version_checked=$2
    echo "Version is $version_supplied"
    echo "Version being checked for is $version_checked"
    local winner=$(echo -e "$version_supplied\n$version_checked" \
      | sed '/^$/d' \
      | sort -t. -k 1,1nr -k 2,2nr -k 3,3nr -k 4,4nr \
      | head -1)
    if [[ $version_supplied == $winner ]] ; then
        version_equals_or_exceeds_check=true
    else
        version_equals_or_exceeds_check=false
    fi
}

# Returns the full path to the executable Docker command.
docker_command_path()
{
    echo "Finding path to Docker executable file ..."
    #
    # TODO: Consider using 'type -P' rather than 'command -v' here; see
    # http://www.cyberciti.biz/faq/unix-linux-shell-find-out-posixcommand-exists-or-not/
    #
    local docker_cmd=`command -v docker`
    if [ -z "$docker_cmd" ]
      then
        # Name of docker command as installed, as of 2014-07-02,
        # by the provided package in Ubuntu 14.04.
        # See http://blog.docker.com/2014/04/docker-in-ubuntu-ubuntu-in-docker/#comment-1146
        docker_cmd=`command -v docker.io`
    fi
    if [ -z "$docker_cmd" ]
      then 
        echo "Error: Could not find Docker command; exiting ..."
        exit 1
    fi
    # Setting or updating a global variable, here, is the simplest (if not
    # the most elegant or error-free) method of returning it to the caller.
    # See http://www.linuxjournal.com/content/return-values-bash-functions
    DOCKER_CMD=$docker_cmd
    echo "Found Docker executable file at $DOCKER_CMD"
}

# Returns the Docker version.
docker_version()
{
    echo "Obtaining Docker version ..."
    # Outputs a string like 'Docker version 1.0.1, build 990021a'
    local docker_long_version=`$DOCKER_CMD --version`
    if [ -z "$docker_long_version" ]
      then
        echo "Error: Could not find Docker version; exiting ..."
        exit 1
    fi
    TMPFILE=`mktemp /tmp/docker_version.XXXXXXXXXX` || exit 1
    echo "$docker_long_version" > TMPFILE
    # TODO: The following simple regex is brittle, and will fail to return a
    # value if the version number doesn't exactly follow the n.n.n pattern below,
    # or the complete version string changes at some future point. We might
    # tweak this to handle a wider variety of numbers. In addition, we might
    # instead parse the more verbose, but possibly more stable, output from
    # 'docker version' (i.e. not 'docker --version').
    docker_parsed_version=$(sed -n 's#^Docker version \([0-9]\.[0-9]\.[0-9]\).*#\1#p' TMPFILE)
    if [ -z "$docker_parsed_version" ]
      then 
        echo "Error: Could not successfully parse Docker version; exiting ..."
        exit 1
    fi
    # Setting or updating a global variable, here, is the simplest (if not
    # the most elegant or error-free) method of returning it to the caller.
    # See http://www.linuxjournal.com/content/return-values-bash-functions
    DOCKER_VERSION=$docker_parsed_version
    echo "Docker version is $DOCKER_VERSION"
}

# ###############################################################
# Ensure that we have the latest version of Docker installed
# See http://docs.docker.com/installation/ubuntulinux/
# ###############################################################

# Check that the installed Docker executable equals or exceeds
# a minimum required version.

DOCKER_MIN_VERSION_REQUIRED=1.0
docker_command_path
docker_version
check_version $DOCKER_VERSION $DOCKER_MIN_VERSION_REQUIRED
if [[ "$version_equals_or_exceeds_checked_version" == true ]] ; then
  echo "Docker version requirement has been met"
  docker_upgrade_required=false
else
  docker_upgrade_required=true
fi

#
# If the Docker executable does not equal or exceed the minimum
# required version, add the APT repository configuration from
# Docker.io, and then install the latest available Docker package.
#
if [[ "$docker_upgrade_required" == true ]]; then

    echo "Upgrading Docker ..."
    
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

    #
    # Get the name of the Docker command once again, following the upgrade.
    #
    # (Under at least one circumstance - in Ubuntu 14.04, upgrading from
    # built-in 0.9.1 Docker to an - as of this writing - 1.0.1 or later
    # Docker version, the command name will change from 'docker.io' to
    # 'docker' after the upgrade.)
    #
    docker_command_path

fi

# Uncomment when debugging setup code above
# echo "Script exiting prematurely here: this should only happen when debugging setup code ..."
# exit 0

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
echo "Building CollectionSpace Base image ..."
sudo $DOCKER_CMD build --rm=true --tag=collectionspace/cspace-base ./cspace-base               
echo "Building CollectionSpace Version-specific image ..."
sudo $DOCKER_CMD build --rm=true --tag=collectionspace/cspace-version ./cspace-provision-version  

#
# Read values from a per-instance configuration file and substitute
# those values for placeholder macros within a template Dockerfile, thus
# generating a Dockerfile specific to a particular instance of CollectionSpace.
#
# This Dockerfile will be used to build the third and last image, below.
#
echo "Updating Dockerfile with instance-specific values ..."
sed -f ./cspace-provision-instance/cspace-instance-values.sed \
  ./cspace-provision-instance/Dockerfile.template > ./cspace-provision-instance/Dockerfile

#
# Build the third image.
#
echo "Building CollectionSpace Instance-specific image ..."
sudo $DOCKER_CMD build --rm=true --tag=collectionspace/cspace-instance ./cspace-provision-instance
