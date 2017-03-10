#!/bin/bash

# Functions
dockerCleanUp() {
    # This checks whether munki munki-do etc are running and stops them if so
    # (thanks to Pepijn Bruienne):
    echo "### Stopping and removing old Docker instances..."
    docker ps -a | sed "s/\ \{2,\}/$(printf '\t')/g" | \
        awk -F"\t" '/apache|munki|sal|postgres-sal|mwa2|munki-do/{print $1}' | \
        xargs docker rm -f
    echo "### ...done"
    echo
}

createDatabaseFolder() {
    echo "### checking for $1 database folder"
    echo
    # ensure there's a folder ready for the $1 database:
    if [[ ! -d "$1" ]]; then
        mkdir -p $1
    fi
}

# -------------------------------------------------------------------------------------- #
## Main section

# import the settings
. settings.sh

# double-check that the Munki repo exists
if [ ! -d "$MUNKI_REPO" ]; then
    echo "### Munki Repo not set up. Please run munkiinabox.sh before running this script"
    echo "### Exiting..."
    echo
    exit 0
fi

# if we got this far then we can install the munki server

# Stop any running docker containers
dockerCleanUp

echo "### checking for Sal database folder"
echo
createDatabaseFolder "$SAL_DB"

# ensure there's a folder ready for the MWA2 DB:
if [[ $MWA2_ENABLED = true ]]; then
    createDatabaseFolder "$MWA2_DB"
fi

# ensuring the Munki-Do DB folder exists with the correct permissions
if [[ $MUNKI_DO_ENABLED = true ]]; then
    createDatabaseFolder "$MUNKI_DO_DB"
fi

# Start the Munki server container
echo "### Munki Server Docker..."
docker run -d --restart=always --name="munki" \
    -v $MUNKI_REPO:/munki_repo \
    -p $MUNKI_PORT:80 -h munki groob/docker-munki

# Optionally start a MunkiWebAdmin2 container
if [[ $MWA2_ENABLED = true ]]; then
    echo
    echo "### MunkiWebAdmin2 Server Docker..."
    # munkiwebadmin2 container
    docker run -d --restart=always --name "mwa2" \
        -p $MWA2_PORT:8000 \
        -v $MUNKI_REPO:/munki_repo \
        -v $MWA2_DB:/mwa2-db \
        grahamrpugh/mwa2
fi

# Start a Sal container
echo
echo "### Sal Server Docker..."
docker run -d --name="sal" \
  --restart="always" \
  -p $SAL_PORT:8000 \
  -v $SAL_DB:/home/docker/sal/db \
  -e ADMIN_PASS=pass \
  -e DOCKER_SAL_TZ="Europe/Zurich" \
  macadmins/sal
  
# Optionally start a Munki-Do container
if [[ $MUNKI_DO_ENABLED = true ]]; then
    echo
    echo "### Munki-Do Docker..."
    docker run -d --restart=always --name munki-do \
        -p $MUNKI_DO_PORT:8000 \
        -v $MUNKI_REPO:/munki_repo \
        -v $MUNKI_DO_DB:/munki-do-db \
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
echo "--- SAL SETUP ---"
echo "Don't forget to set your Sal client preferences. Open Sal at the address below,"
echo "create a business unit and a machine group, and then copy the key into "
echo "a shell script. You then need to run this script on the client, e.g. "
echo "via a Munki package. A good method is to install Munki-Pkg on your computer:"
echo
echo "---"
echo "git clone https://github.com/munki/munki-pkg.git"
echo "cd munki-pkg"
echo "./munkipkg --create sal-preferences"
echo "nano sal-preferences/scripts/postinstall"
echo "---"
echo
echo "Copy the following into postinstall:"
echo
echo "---"
echo "#!/bin/bash"
echo "sudo defaults write /Library/Preferences/com.github.salopensource.sal.plist ServerURL \"http://$IP:$SAL_PORT\""
echo "sudo defaults write /Library/Preferences/com.github.salopensource.sal.plist key \"verylongnumberinSalinterface\""
echo "---"
echo
echo "Then do the following:"
echo
echo "---"
echo "./munkipkg sal-preferences"
echo "munkiimport sal-preferences/build/sal-preferences-1.0.pkg --subdirectory config/sal --unattended-install --displayname=\"Sal Preferences\" --developer=\"Graham Gilbert\" -n"
echo "manifestutil add-pkg sal-preferences --manifest $MUNKI_DEFAULT_SOFTWARE_MANIFEST"
echo "---"
echo 
echo "--- END SAL SETUP ---"
echo
echo "###"
echo "### Your Munki URL is: http://$IP:$MUNKI_PORT"
echo "### Test your Munki URL with: http://$IP:$MUNKI_PORT/$REPONAME/catalogs/all"
if [[ $MWA2_ENABLED = true ]]; then
    echo "### Your MWA2 URL is: http://$IP:$MWA2_PORT"
fi
echo "### Your Sal URL is: http://$IP:$SAL_PORT"
if [[ $MUNKI_DO_ENABLED = true ]]; then
    echo "### Your Munki-Do URL is: http://$IP:$MUNKI_DO_PORT"
fi



