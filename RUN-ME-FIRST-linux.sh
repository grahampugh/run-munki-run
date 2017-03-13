#!/bin/bash

# Run-Munki-Run
# by Graham Pugh

# Run-Munki-Run is a Dockerised Munki setup, with extra tools.

# This Linux setup script will set up the server and basic tools. You need a Mac to manipulate the manifests and run AutoPkg.

# TO DO:
# # Download and install Docker from this script


# -------------------------------------------------------------------------------------- #
## Functions

# Check that the script is NOT running as root
rootCheck() {
    if [[ $EUID -eq 0 ]]; then
        echo "### This script is NOT MEANT to run as root. This script is meant to be run as an admin user. I'm going to quit now. Run me without the sudo, please."
        echo
        exit 4 # Running as root.
    fi
}

createMunkiRepo() {
    munkiFolderList=( "catalogs" "manifests" "pkgs" "pkgsinfo" "icons" )
    for i in ${munkiFolderList[@]}; do
        mkdir -p "$1/$i"
        echo "### $i folder present and correct!"
    done
    ${LOGGER} "Repo present and correct!"
    echo

    chmod -R a+rX,g+w "$1" ## Thanks Arek!
    chown -R ${USER}:admin "$1" ## Thanks Arek!
    ${LOGGER} "### Repo permissions set"
}


# -------------------------------------------------------------------------------------- #
## Main section

# Establish our Basic Variables:
. settings-linux.sh

# Set proxy if populated
if [[ -z $HTTP_PROXY ]]; then
    export http_proxy=$HTTP_PROXY
fi
if [[ -z $HTTPS_PROXY ]]; then
    export https_proxy=$HTTPS_PROXY
fi


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

# 10.10+ for the Web Root Location.
versionCheck 10

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
