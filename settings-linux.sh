#!/bin/bash

# Munki Repo location (path)
REPOLOC="/media/psf"
# Repo folder name
REPONAME="repo"

# HTTP or HTTPS?
# You can direct to https if you like. You would have to have a valid certificate
# already on the server. This is most suited to those of you serving the Munki
# folders via Server.app or a native Nginx/Apache installation.
# If you're running the Docker-Munki container, then this isn't so easy
# to automate. I suggest taking a look at: http://aulin.co/2015/Munki-SSL-Docker/
# and changing the docker run command in run-munki-run.sh.
HTTP_PROTOCOL="http"

# HTTP Basic Authentication password
HTPASSWD="CHANGE_ME!!!NO_REALLY!!!"

# What do you want to call your Munki software manifest?
# site_default will be created, and this manifest will be added as an
# included_manifest
MUNKI_DEFAULT_SOFTWARE_MANIFEST="core_software"



# Docker variables

# Databases location. This should be away from shared directories e.g. the web root.
DBLOC="$HOME/munki-databases"

# Munki container variables:
# Enabled by default. Set to true if you wish to have a Docker Munki server.
# Set to false if you are using something else to serve Munki e.g. Server.app
MUNKI_ENABLED=true
# Set the public port on which you wish to access Munki
MUNKI_PORT=8000

## Sal settings:
# Enabled by default. Set to true if you wish to use Sal:
SAL_ENABLED=true
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
