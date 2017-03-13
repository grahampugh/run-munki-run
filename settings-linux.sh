#!/bin/bash

# Munki Repo location. This should be in /Users somewhere (not tested lately)
REPOLOC="$HOME"
REPONAME="repo"
MUNKI_REPO="${REPOLOC}/${REPONAME}"
MUNKI_DEFAULT_SOFTWARE_MANIFEST="core_software"

# Databases location. This should be away from shared directories e.g. the web root.
DBLOC="$HOME/munki-databases"

# Commands
MUNKILOC="/usr/local/munki"
GIT="/usr/bin/git"
MANU="/usr/local/munki/manifestutil"

# Some other directories
SCRIPTDIR="/usr/local/bin"

# Docker variables

# Munki container variables:
# Set the public port on which you wish to access Munki
# Note: Docker-Machine with VirtualBox cannot forward ports under 1024
MUNKI_PORT=8000

## Sal settings:
# Create a new folder to house the Sal Django database and point to it here:
# If using Docker-Machine, it must be within /Users somewhere:
SAL_DB="${DBLOC}/sal-db"
# Set the public port on which you wish to access Sal
SAL_PORT=8001

## MWA2 settings:
# Enabled by default. Set to true if you wish to use Munki-Do:
MWA2_ENABLED=false
# Create a new folder to house the MWA2 Django database and point to it here:
# If using Docker-Machine, it must be within /Users somewhere:
MWA2_DB="${DBLOC}/mwa2-db"
# Set the public port on which you wish to access MWA2
MWA2_PORT=8003

## Munki-Do settings:
# Disabled by default. Set to true if you wish to use Munki-Do:
MUNKI_DO_ENABLED=true
# Create a new folder to house the Munki-Do Django database and point to it here.
# If using Docker-Machine, it must be within /Users somewhere:
MUNKI_DO_DB="${DBLOC}/munki-do-db"
# Set the public port on which you wish to access Munki-Do
MUNKI_DO_PORT=8002
#
# Set Munki-Do manifest item search to all items rather than just in current catalog:
ALL_ITEMS=true
#
# Munki-Do opens on the '/catalog' pages by default. Set to "/pkgs" or "/manifest" if you
# wish to change this behaviour:
LOGIN_REDIRECT_URL="/pkgs"
#
# Munki-Do timezone is 'Europe/Zurich' by default, but you can change to whatever you
# wish using the codes listed at http://en.wikipedia.org/wiki/List_of_tz_zones_by_name
TIME_ZONE='Europe/Zurich'

# logger
LOGGER="/usr/bin/logger -t Run-Munki-Run"

# IP address
# If your PC has more than one interface, you'll need to change to eth1 to the appropirate interface.
IP=$(ip addr show dev eth1 | grep "inet " | awk '{ print $2 }')

