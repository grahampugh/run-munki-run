#!/bin/bash

# run-munki-run.sh
# This script can be run independently of RUN-ME-FIRST.sh to restart the docker services on
# a system that has already been setup using RUN-ME-FIRST.sh.

# Functions

rootCheck() {
    # Check that the script is NOT running as root
    if [[ $EUID -eq 0 ]]; then
        echo "### This script is NOT MEANT to run as root. This script is meant to be run as an admin user. I'm going to quit now. Run me without the sudo, please."
        echo
        exit 4 # Running as root.
    fi
}

dockerCleanUp() {
    # This checks whether munki munki-do etc are running and stops them if so
    # (thanks to Pepijn Bruienne):
    echo "### Stopping and removing old Docker instances..."
    docker ps -a | sed "s/\ \{2,\}/$(printf '\t')/g" | \
        awk -F"\t" '/apache|munki|sal|postgres-sal|mwa2|munki-do|auth|web/{print $1}' | \
        xargs docker rm -f
    echo "### ...done"
    echo
}

createDatabaseFolder() {
    echo
    echo "### checking for $1 database folder"
    echo
    # ensure there's a folder ready for the $1 database:
    if [[ ! -d "$1" ]]; then
        mkdir -p $1
    fi
}

# -------------------------------------------------------------------------------------- #
## Main section

# logger
LOGGER="/usr/bin/logger -t Run-Munki-Run"

# import the settings
if [[ $1 == "linux" ]]; then
    echo "### Importing Linux setup..."
    . settings-linux.sh
else
    echo "### Importing Mac setup..."
    . settings.sh
fi

#Let's see if this works...
#This isn't bulletproof, but this is a basic test.
sudo whoami > /tmp/quickytest

if [[ $(cat /tmp/quickytest) == "root" ]]; then
    ${LOGGER} "Privilege Escalation Allowed, Please Continue."
else
    ${LOGGER} "Privilege Escalation Denied, User Cannot Sudo."
    echo "### You are not an admin user, you need to do this an admin user."
    echo
    exit 1
fi

# Check that the script is NOT running as root
rootCheck

# What type of Docker do we have?
# Run additional setup steps if using Docker Toolbox
if ls /var/run/docker.sock 2> /dev/null && docker ps -q 2> /dev/null ; then
    DOCKER_TYPE="native"
elif which docker-machine && -d "/Applications/VirtualBox.app" && ! docker ps -q 1> /dev/null ; then
    DOCKER_TYPE="docker-machine"
# Docker-machine is running but env is wrong
elif [[ $(which docker-machine) && -d "/Applications/VirtualBox.app" && $(docker-machine ls | grep default | grep Running) ]]; then
    echo
    echo "--- ACTION REQUIRED ---"
    echo "Docker Toolbox is installed and running, but you need to set up the shell environment to run docker commands"
    echo "Please run the following commands:"
    echo
    echo "docker-machine env default"
    echo 'eval $(docker-machine env default)'
    echo
    echo "Then re-run ./run-munki-run.sh"
    echo "---"
    echo
    exit 0
# docker-machine is stopped
elif [[ $(which docker-machine) && -d "/Applications/VirtualBox.app" && $(docker-machine ls | grep default | grep Stopped) ]]; then
    echo
    echo "--- ACTION REQUIRED ---"
    echo "Docker Toolbox is installed but has stopped."
    echo "Please run the following command:"
    echo
    echo "docker-machine restart default"
    echo
    echo "Then re-run ./run-munki-run.sh"
    echo "---"
    echo
    exit 0
# Check if this is a Mac
elif [[ -d "/Applications/Safari.app" ]]; then
    echo
    echo "--- ACTION REQUIRED ---"
    echo "You do not appear to have Docker installed (or it is not running)."
    echo "If the app is installed, make sure it is running."
    echo "or go to Docker.com and get the native Docker for Mac (new Macs since 2010)"
    echo "or the Docker Toolbox (older Macs)"
    echo "---"
    echo
    exit 0
else
    echo
    echo "--- CANNOT CONTINUE ---"
    echo "This doesn't appear to be a Mac! Linux support may come in the future. Windows, no."
    echo "---"
    echo
    exit 0
fi

echo
echo "### Docker type: $DOCKER_TYPE"
echo

if [[ $DOCKER_TYPE == "docker-machine" ]]; then
    # Extra setup steps are required for old Macs running Docker-Toolbox
    . docker-machine.sh
fi

# double-check that the Munki repo exists
if [[ ! -d "$MUNKI_REPO" ]]; then
    echo "### Munki Repo not set up. Please run RUN-ME-FIRST.sh before running this script"
    echo "### Exiting..."
    echo
    exit 0
fi

# if we got this far then we can run the munki server container

# Stop any running docker containers
dockerCleanUp

# Start the Munki server container
echo "### Munki Server Docker..."
if [[ $MUNKI_ENABLED == true ]]; then
    docker run -d --restart=always --name="munki" \
        -v $MUNKI_REPO:/munki_repo \
        -p $MUNKI_PORT:80 -h munki grahamrpugh/docker-munki

#     # Nginx middleware container for HTTP basic authentication
#     # See https://github.com/beevelop/docker-nginx-basic-auth
#     HTPASSWD_CONTENT=$(sudo head -n 1 $MUNKI_REPO/.htpasswd)
#     echo $HTPASSWD_CONTENT
#     docker run -d \
#         -e HTPASSWD=$HTPASSWD_CONTENT \
#         -e FORWARD_PORT=8765 \
#         --link web:web -p $MUNKI_PORT:80 \
#         --name auth \
#         beevelop/nginx-basic-auth
fi

# Start a MunkiWebAdmin2 container
if [[ $MWA2_ENABLED == true ]]; then
    # Check for mwa2-db folder
    createDatabaseFolder "$MWA2_DB"
    echo
    echo "### MunkiWebAdmin2 Server Docker..."
    # munkiwebadmin2 container
    docker run -d --restart=always --name "mwa2" \
        -p $MWA2_PORT:8000 \
        -v $MUNKI_REPO:/munki_repo \
        -v $MWA2_DB:/mwa2-db \
        -e ADMIN_PASS=$ADMIN_PASSWORD \
        macadmins/mwa2
fi

# Start a Sal container
if [[ $SAL_ENABLED == true ]]; then
    # Check for sal-db folder
    createDatabaseFolder "$SAL_DB"
    echo
    echo "### Sal Server Docker..."
    docker run -d --name="sal" \
      --restart="always" \
      -p $SAL_PORT:8000 \
      -v $SAL_DB:/home/docker/sal/db \
      -e ADMIN_PASS=$ADMIN_PASSWORD \
      -e DOCKER_SAL_TZ="Europe/Zurich" \
      macadmins/sal
fi

# Start a Munki-Do container
if [[ $MUNKI_DO_ENABLED == true ]]; then
    # Check for munki-do-db folder
    createDatabaseFolder "$MUNKI_DO_DB"
    echo
    echo "### Munki-Do Docker..."
    docker run -d --restart=always --name munki-do \
        -p $MUNKI_DO_PORT:8000 \
        -v $MUNKI_REPO:/munki_repo \
        -v $MUNKI_DO_DB:/munki-do-db \
        -e ADMIN_PASS=$ADMIN_PASSWORD \
        -e DOCKER_MUNKIDO_TIME_ZONE="$TIME_ZONE" \
        -e DOCKER_MUNKIDO_LOGIN_REDIRECT_URL="$LOGIN_REDIRECT_URL" \
        -e DOCKER_MUNKIDO_ALL_ITEMS="$ALL_ITEMS" \
        -e DOCKER_MUNKIDO_GIT_PATH="" \
        -e DOCKER_MUNKIDO_GIT_BRANCHING="" \
        grahamrpugh/munki-do
fi

# final messages...
echo
echo "### All done!"
echo
echo "--- SAL SETUP INSTRUCTIONS ---"
echo
echo "1. Open Sal at $HTTP_PROTOCOL://$IP:$SAL_PORT"
echo "2. Create a business unit named 'Default' and a machine group named 'site_default'."
echo "3. Choose the 'person' menu at the top right and then choose Settings."
echo "4. From the sidebar, choose API keys and then choose to make a new one."
echo "5. Give it a name so you can recognise it - e.g. 'PKG Generator'."
echo "6. You will then be given a public key and a private key."
echo "7. Enter the following command in terminal to generate the enroll package:"
echo
echo "python sal_package_generator.py --sal_url=$HTTP_PROTOCOL://$IP:$SAL_PORT --public_key=<PUBLIC_KEY> --private_key=<PRIVATE_KEY> --pkg_id=com.salopensource.sal_enroll"
echo
echo "8. Enter the following commands to import the package to Munki:"
echo
echo "munkiimport sal-enroll-site_default.pkg --subdirectory config/sal --unattended-install --displayname=\"Sal Enrollment for site_default\" --developer=\"Graham Gilbert\" -n"
echo "manifestutil add-pkg sal-enroll-site_default --manifest $MUNKI_DEFAULT_SOFTWARE_MANIFEST"
echo "makecatalogs"
echo
echo "--- END OF SAL SETUP INSTRUCTIONS ---"
echo
echo "--- DETAILS ---"
echo
echo "Your Munki URL is: $HTTP_PROTOCOL://$IP:$MUNKI_PORT"
echo "(test your Munki URL with: $HTTP_PROTOCOL://$IP:$MUNKI_PORT/$REPONAME/catalogs/all)"
if [[ $MWA2_ENABLED = true ]]; then
    echo "Your MWA2 URL is: $HTTP_PROTOCOL://$IP:$MWA2_PORT"
fi
if [[ $MUNKI_DO_ENABLED = true ]]; then
    echo "Your Munki-Do URL is: $HTTP_PROTOCOL://$IP:$MUNKI_DO_PORT"
fi
echo "Your Sal URL is: $HTTP_PROTOCOL://$IP:$SAL_PORT"
echo
echo "Download the Munki Client Installer Pkg on a client from the following URL:"
echo
echo "$HTTP_PROTOCOL://$IP:$MUNKI_PORT/$REPONAME/installers/ClientInstaller.pkg"
echo
echo "To update Autopkg recipes in the future, run the following command:"
echo
echo "autopkg run --recipe-list \"${AUTOPKG_RECIPE_LIST}\""
echo
