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

# ensure there's a folder ready for the MWA2 DB:
if [[ $MWA2_ENABLED = true ]]; then
	if [[ ! -d "$MWA2_DB" ]]; then
		mkdir -p $MWA2_DB
		# chmod and chown if you need to!
	fi
fi

# ensuring the Munki-Do DB folder exists with the correct permissions
if [[ $MUNKI_DO_ENABLED = true ]]; then
	if [[ ! -d "$MUNKI_DO_DB" ]]; then
    	mkdir -p "$MUNKI_DO_DB"
    	# chmod and chown if you need to!
	fi
fi

echo "### Munki Server Docker..."
# Munki server container
docker run -d --restart=always --name="munki" \
	-v $MUNKI_REPO:/munki_repo \
	-p $MUNKI_PORT:80 -h munki groob/docker-munki

# optional setup of MunkiWebAdmin2
if [[ $MWA2_ENABLED = true ]]; then
	echo "### MunkiWebAdmin2 Server Docker..."
	# munkiwebadmin2 container
	docker run -d --restart=always --name "mwa2" \
		-p $MWA2_PORT:8000 \
		-v $MUNKI_REPO:/munki_repo \
		-v $MWA2_DB:/mwa2-db \
		grahamrpugh/mwa2
fi

echo "### Sal Server Docker..."
#sal-server container
docker run -d --name="sal" \
  --restart="always" \
  -p $SAL_PORT:8000 \
  -v $SAL_DB:/home/docker/sal/db \
  -e ADMIN_PASS=pass \
  -e DOCKER_SAL_TZ="Europe/Zurich" \
  macadmins/sal
  
# optional setup of Munki-Do
if [[ $MUNKI_DO_ENABLED = true ]]; then
	# munki-do container
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

echo
echo "### All done!"
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
echo "manifestutil add-pkg sal-preferences --manifest site_default"
echo "---"
echo 
echo "--- END SAL SETUP ---"

# final messages...
echo
echo
echo "### All done!"
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
echo
echo




