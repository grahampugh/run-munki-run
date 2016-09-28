#!/bin/bash

# import the settings
. settings.sh

if [ ! -d "$MUNKI_REPO" ]; then
	echo "### Munki Repo not set up. Please run munkiinabox.sh before running this script"
	echo "### Exiting..."
	echo
	exit 0
fi

# if we got this far then we can install munki


# Clean up
. cleanup.sh

echo "### checking for Sal database folder"
echo
# ensure there's a folder ready for the Sal DB:
if [[ ! -d "$SAL_DB" ]]; then
    mkdir -p $SAL_DB
    # chmod and chown if you need to!
fi

echo "### Munki Server Docker..."
# Munki server container
docker run -d --restart=always --name="munki" \
	-v $MUNKI_REPO:/munki_repo \
	-p $MUNKI_PORT:80 -h munki groob/docker-munki

echo "### MunkiWebAdmin2 Server Docker..."
# munkiwebadmin2 container
docker run -d --restart=always --name "mwa2" \
	-p $MWA2_PORT:8000 \
	-v $MUNKI_REPO:/munki_repo \
	-v $MWA2_DB:/mwa2-db \
	grahamrpugh/mwa2

echo "### Sal Server Docker..."
#sal-server container
docker run -d --name="sal" \
  --restart="always" \
  -p $SAL_PORT:8000 \
  -v $SAL_DB:/home/docker/sal/db \
  -e ADMIN_PASS=pass \
  -e DOCKER_SAL_TZ="Europe/Berlin" \
  macadmins/sal

echo
echo "### All done!"
echo "###"
echo "### Your Munki URL is: http://$IP:$MUNKI_PORT"
echo "### Test your Munki URL with: http://$IP:$MUNKI_PORT/$REPONAME/catalogs/all"
echo "### Your MWA2 URL is: http://$IP:$MWA2_PORT"
echo "### Your Sal URL is: http://$IP:$SAL_PORT"
echo
echo "Don't forget to set your Sal client preferences. Open Sal at the above address,"
echo "create a business unit and a machine group, and then copy the key into "
echo "sal-client-setup.sh. You then need to run this file on the client, e.g. "
echo "via a Munki package:"
echo 
echo "---"
echo "#!/bin/bash"
echo "sudo defaults write /Library/Preferences/com.github.salopensource.sal.plist ServerURL \"http://$IP:$SAL_PORT\""
echo "sudo defaults write /Library/Preferences/com.github.salopensource.sal.plist key \"verylongnumberinSalinterface\""
echo "---"
echo



