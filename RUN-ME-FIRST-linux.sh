#!/bin/bash

# Run-Munki-Run
# by Graham Pugh

# Run-Munki-Run is a Dockerised Munki setup, with extra tools.

# This Linux setup script will set up the server and basic tools. You need a Mac to manipulate the manifests and run AutoPkg.

# TO DO:
# # Download and install Docker from this script


# -------------------------------------------------------------------------------------- #
## Functions

rootCheck() {
    # Check that the script is NOT running as root
    if [[ $EUID -eq 0 ]]; then
        echo "### This script is NOT MEANT to run as root. This script is meant to be run as an admin user. I'm going to quit now. Run me without the sudo, please."
        echo
        exit 4 # Running as root.
    fi
}

createMunkiRepo() {
    # Creates the Munki repo folders if they don't already exist
    # Inputs: 1. $MUNKI_REPO
    munkiFolderList=( "catalogs" "manifests" "pkgs" "pkgsinfo" "icons" )
    for i in ${munkiFolderList[@]}; do
        mkdir -p "$1/$i"
        echo "### $i folder present and correct!"
    done
    ${LOGGER} "Repo present and correct!"
    echo

    chmod -R a+rX,g+w "$1" ## Thanks Arek!
    chown -R ${USER} "$1"
    ${LOGGER} "### Repo permissions set"
}


# -------------------------------------------------------------------------------------- #
## Main section

# Commands
MUNKILOC="/usr/local/munki"
GIT="/usr/bin/git"
MANU="/usr/local/munki/manifestutil"

# IP address
# If your PC has more than one interface, you'll need to change to eth1 to the appropirate interface.
IP=$(ip addr show dev eth1 | grep "inet " | awk '{ print $2 }' | sed -e 's/\/.*//g')

# Establish our Basic Variables:
. settings-linux.sh

# Path to Munki repo
MUNKI_REPO="${REPOLOC}/${REPONAME}"

# logger
LOGGER="/usr/bin/logger -t Run-Munki-Run"

echo
echo "### Welcome to Run-Munki-Run, a reworking of Tom Bridge's awesome Munki-In-A-Box."
echo "### We're going to get things rolling here with a couple of tests"'!'
echo
echo "### First up: Are you an admin user? Enter your password below:"
echo

#Let's see if this works...
#This isn't bulletproof, but this is a basic test.
sudo whoami > /tmp/quickytest

if [[ $(cat /tmp/quickytest) == "root" ]]; then
    ${LOGGER} "Privilege Escalation Allowed, Please Continue."
else
    ${LOGGER} "Privilege Escalation Denied, User Cannot Sudo."
    echo "### You are not an admin user, you need to do this an admin user."
    exit 1
fi

${LOGGER} "Starting up..."

## Checks

# Check that the script is NOT running as root
rootCheck

echo "### Great. All Tests are passed, so let's create the Munki Repo"'!'
echo
${LOGGER} "All Tests Passed! On to the configuration."

# Create the repo
createMunkiRepo "${MUNKI_REPO}"

${LOGGER} "All done."

echo
echo "### You should now have a populated repo!"
echo "### Now let's start the Munki server..."
echo

# This autoruns the second script, if it's there!
if [[ -f "run-munki-run.sh" ]]; then
    . run-munki-run.sh linux
fi

exit 0
