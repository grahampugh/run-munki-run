#!/bin/bash

# Edit this location to point to your munki_repo. It must be within /Users somewhere:
REPOLOC="/Users/Shared"
REPONAME="repo"
MUNKI_REPO="${REPOLOC}/${REPONAME}"
# Munki container variables
# If you have access to DNS, use the Apache container to proxy each Docker web service
# to a hostname. I recommend "munki" for the Munki host so you don't need to set a 
# preference.
MUNKI_HOSTNAME="munki.grahamrpugh.com"
# Set the public port on which you wish to access Munki 
MUNKI_PORT=8008
# Location for virtual hosts
VIRTUALHOSTSLOC="${REPOLOC}/sites-available"
# Create a new folder to house the Munki-Do Django database and point to it here.
# If using Docker-Machine, it must be within /Users somewhere:
SAL_DB="${REPOLOC}/sal-db"
# Sal hostname, if you have DNS aliases setup
SAL_HOSTNAME="sal.grahamrpugh.com"
# Set the public port on which you wish to access Sal 
SAL_PORT=8080
# Create a new folder to house the MWA2 Django database and point to it here:
# If using Docker-Machine, it must be within /Users somewhere:
MWA2_DB="${REPOLOC}/mwa2-db"
# MWA2 hostname, if you have DNS aliases setup
MWA2_HOSTNAME="mwa2.grahamrpugh.com"
# Set the public port on which you wish to access MWA2 
MWA2_PORT=8088
# IP address
IP=`ipconfig getifaddr en0`

if [ ! -d "$MUNKI_REPO" ]; then
	echo "Munki Repo not set up. Please run munkiinabox.sh before running this script"
	echo "Exiting..."
	echo
	exit 0
fi

# if we got this far then we can install munki


# Clean up
# This checks whether munki munki-do etc are running and stops them
# if so (thanks to Pepijn Bruienne):
docker ps -a | sed "s/\ \{2,\}/$(printf '\t')/g" | \
	awk -F"\t" '/apache|munki|sal|postgres-sal|mwa2/{print $1}' | \
	xargs docker rm -f
	
# ensure there's a folder for the virtual hosts files
if [[ ! -d "$VIRTUALHOSTSLOC" ]]; then
    mkdir -p $VIRTUALHOSTSLOC
    # chmod and chown if you need to!
	# create the virtual hosts files:
	## Munki:
	cat > "$VIRTUALHOSTSLOC/$MUNKI_HOSTNAME.conf" <<'ENDMSG'
<VirtualHost *:80>
	ServerName $MUNKI_HOSTNAME
	<Proxy *>
	Allow from localhost
	</Proxy>
	ProxyPass / http://$IP:$MUNKI_PORT/
	</VirtualHost>
ENDMSG
	## Sal:
	cat > "$VIRTUALHOSTSLOC/$SAL_HOSTNAME.conf" <<'ENDMSG'
<VirtualHost *:80>
	ServerName $SAL_HOSTNAME
	<Proxy *>
	Allow from localhost
	</Proxy>
	ProxyPass / http://$IP:$SAL_PORT/
	</VirtualHost>
ENDMSG
	## MWA2
	cat > "$VIRTUALHOSTSLOC/$SAL_HOSTNAME.conf" <<'ENDMSG'
<VirtualHost *:80>
	ServerName $MWA2_HOSTNAME
	<Proxy *>
	Allow from localhost
	</Proxy>
	ProxyPass / http://$IP:$MWA2_PORT/
	</VirtualHost>
ENDMSG
fi

# ensure there's a folder ready for the Sal DB:
if [[ ! -d "$SAL_DB" ]]; then
    mkdir -p $SAL_DB
    # chmod and chown if you need to!
fi

# Apache container for virtual hosts
docker run -d --name="apache" \
	-v $VIRTUALHOSTSLOC:/etc/apache2/sites-available \
	-p 80:80 \
	httpd:latest
	
# Munki server container
docker run -d --restart=always --name="munki" \
	-v $MUNKI_REPO:/munki_repo \
	-p $MUNKI_PORT:80 -h munki groob/docker-munki


# munkiwebadmin2 container
docker run -d --restart=always --name "mwa2" \
	-p $MWA2_PORT:8000 \
	-v $MUNKI_REPO:/munki_repo \
	-v $MWA2_DB:/mwa2-db \
	grahamrpugh/mwa2


#sal-server container
docker run -d --name="sal" \
  --restart="always" \
  -p $SAL_PORT:8000 \
  -v $SAL_DB:/home/docker/sal/db \
  -e ADMIN_PASS=pass \
  -e DOCKER_SAL_TZ="Europe/Berlin" \
  macadmins/sal

# renable virtual hosts and estart Apache in the apache container
docker exec apache a2ensite $MUNKI_HOSTNAME.conf
docker exec apache a2ensite $SAL_HOSTNAME.conf
docker exec apache a2ensite $MWA2_HOSTNAME.conf
docker exec apache service apache2 reload

echo
echo "#########"
echo "### All done!"
echo "###"
echo "### Your Munki URL is: http://$MUNKI_HOSTNAME or http://$IP:$MUNKI_PORT"
echo "### Test your Munki URL with: http://$IP:$MUNKI_PORT/repo/catalogs/all"
echo "### Your MWA2 URL is: http://$SAL_HOSTNAME or http://$IP:$MWA2_PORT"
echo "### Your Sal URL is: http://$MWA2_HOSTNAME or http://$IP:$SAL_PORT"
echo
echo "Don't forget to set your Sal client preferences. Open Sal at the above address,"
echo "create a business unit and a machine group, and then copy the key into "
echo "sal-client-setup.sh. You then need to run this file on the client, e.g. "
echo "via a package."
echo 


