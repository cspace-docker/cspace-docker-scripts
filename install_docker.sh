#!/usr/bin/env bash

# Install the latest version of Docker on a Debian-based Linux
# system (including Ubuntu).
#
# Installation will be performed if:
#
# * Docker isn't present; or
# * Docker is present but its version is lower than a minimum
#   required version.

# ###############################################################
# Variables to configure
# ###############################################################

# Specify a minimum required version for Docker (in n.n or n.n.n format,
# e.g. 1.0, 1.1.2, or - hypothetically - 12.6.5)
#
# If Docker is found on the target system, installation will
# only be performed only if the minimum required version,
# below, isn't already present. This allows you to retain
# a stable version of Docker, and upgrade it only when needed.
#
# To always force the installation of the latest available version
# of Docker, set the minimum version below to an arbitrarily high
# value; e.g. 500.0.0
#
DOCKER_MINIMUM_VERSION_REQUIRED=1.2.0

# ###############################################################

# TODO: Provide a less kludgy way to always force installation
# of the latest version of Docker.
#
# TODO: Allow specifying the minimum required version via a
# command line option.

# Uncomment for verbose debugging
# set -x

# ###############################################################
# Utility functions
# ###############################################################

#
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
#
check_version()
{
    echo "Checking version ..."
    local version_supplied=$1
    local version_checked=$2
    echo "Version is $version_supplied"
    echo "Version being checked for is $version_checked"
    local winner=$(echo -e "$version_supplied\n$version_checked" \
      | sed '/^$/d' \
      | sort -t. -k 1,1nr -k 2,2nr -k 3,3nr -k 4,4nr \
      | head -1)
    if [[ $version_supplied == $winner ]] ; then
        VERSION_EQUALS_OR_EXCEEDS_CHECKED_VERSION=true
    else
        VERSION_EQUALS_OR_EXCEEDS_CHECKED_VERSION=false
    fi
}

# Returns the full path to the executable Docker command.
docker_command_path()
{
    echo "Identifying path to Docker executable file ..."
    #
    # TODO: Consider using 'type -P' rather than 'command -v' here; see
    # http://www.cyberciti.biz/faq/unix-linux-shell-find-out-posixcommand-exists-or-not/
    #
    local docker_cmd=`command -v docker`
    if [ -z "$docker_cmd" ]
      then
        #
        # Name of docker command as installed, as of 2014-07-02,
        # by the provided package in Ubuntu 14.04.
        # See http://blog.docker.com/2014/04/docker-in-ubuntu-ubuntu-in-docker/#comment-1146
        #
        docker_cmd=`command -v docker.io`
    fi
    if [ -z "$docker_cmd" ]
      then 
        echo "Could not find Docker command ..."
      else
        #
        # Setting or updating a global variable, here, is the simplest (if not
        # the most elegant or error-free) method of returning it to the caller.
        # See http://www.linuxjournal.com/content/return-values-bash-functions
        #
        DOCKER_CMD=$docker_cmd
        echo "Found Docker executable file at $DOCKER_CMD"
    fi
}

#
# Returns the Docker version.
#
docker_version()
{
    echo "Obtaining Docker version ..."
    #
    # Outputs a string like 'Docker version 1.0.1, build 990021a'
    #
    local docker_long_version=`$DOCKER_CMD --version`
    if [ -z "$docker_long_version" ]
      then
        echo "Error: Could not find Docker version; exiting ..."
        exit 1
    fi
    TMPFILE=`mktemp /tmp/docker_version.XXXXXXXXXX` || exit 1
    echo "$docker_long_version" > TMPFILE
    #
    # TODO: The following simple regex is brittle, and will fail to return a
    # value if the version number doesn't exactly follow the n.n.n pattern below,
    # or the complete version string changes at some future point. We might
    # tweak this to handle a wider variety of numbers. In addition, we might
    # instead parse the more verbose, but possibly more stable, output from
    # 'docker version' (i.e. not 'docker --version').
    #
    docker_parsed_version=$(sed -n 's#^Docker version \([0-9]\.[0-9]\.[0-9]\).*#\1#p' TMPFILE)
    if [ -z "$docker_parsed_version" ]
      then 
        echo "Error: Could not successfully parse Docker version; exiting ..."
        exit 1
    fi
    #
    # Setting or updating a global variable, here, is the simplest (if not
    # the most elegant or error-free) method of returning it to the caller.
    # See http://www.linuxjournal.com/content/return-values-bash-functions
    #
    DOCKER_VERSION=$docker_parsed_version
    echo "Docker version is $DOCKER_VERSION"
}

# ###############################################################
# Ensure that we have the latest version of Docker installed
# See http://docs.docker.com/installation/ubuntulinux/
# ###############################################################

#
# If the Docker command can't be found in the executables path,
# then Docker will be installed.
#
# (The presumption here is that a first-time installation is required
# if Docker can't be found in that path.)
#

#
# Get the path to Docker.
#
docker_command_path
if [ -z "$DOCKER_CMD" ]
  then
    docker_installation_required=true
  else
    #
    # Get the installed Docker version.
    #
    docker_version
    #
    # Check that the installed Docker executable equals or exceeds
    # a minimum required version.
    #
    check_version $DOCKER_VERSION $DOCKER_MINIMUM_VERSION_REQUIRED
    if [[ "$VERSION_EQUALS_OR_EXCEEDS_CHECKED_VERSION" == true ]]
      then
        echo "Docker version requirement has been met"
        docker_upgrade_required=false
      else
        docker_upgrade_required=true
    fi
fi

#
# If the Docker executable does not equal or exceed the minimum
# required version, add the repository configuration from
# Docker.io, and then install the latest available Docker package.
#
if [[ "$docker_installation_required" == true || "$docker_upgrade_required" == true ]]; then

    echo "Installing or upgrading Docker ..."
    
    #
    # TODO: Include blocks for installing or upgrading
    # Docker on both Debian- and Red Hat-based distros.
    #
    
    #
    # Run Docker's own bootstrap script for installing Docker
    #
    echo "Installation/upgrade includes package manager key & repo configuration ..."
    curl -s https://get.docker.io/ubuntu/ | sudo sh
    
    #
    # TODO: Consider switching to newer script that detects,
    # and runs on both Debian- and Red Hat-based distros:
    # https://get.docker.io
    #

    #
    # Get the name of the Docker command once again, following the upgrade.
    #
    # (Under at least one circumstance - in Ubuntu 14.04, upgrading from
    # built-in 0.9.1 Docker to an - as of this writing - 1.0.1 or later
    # Docker version, the command name will change from 'docker.io' to
    # 'docker' after the upgrade.)
    #
    docker_command_path

    #
    # Display the new version number, following the upgrade.
    #
    # (There's an implicit assumption made here that upgrading to
    # the latest version available in the Docker APT repo will
    # always - by definition - meet our minimum requirements for the
    # Docker version. As such, the minimum version check performed
    # above isn't repeated here, before displaying the Docker version.)
    #
    docker_version
fi


