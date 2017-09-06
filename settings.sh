#!/bin/bash

### Settings

# These settings determine how your Munki repository and web services will be configured.
# The defaults are reasonable for a Mac.

# Repo and AutoPkg setup only. Set this value to True if you only want to setup the repository
# and AutoPkg, but do not want to set up the server services (Munki, Munki-Do/MWA2, Sal).
# Possible scenarios for this include:
#  * You are using the Mac Server.app to serve the Munki repo.
#  * You are setting the Munki repo up on a shared folder that is hosted on another computer, such as a Linux VM.
#NOSERVERSETUP=True

# HTTP Basic Authentication password
HTPASSWD="CHANGE_ME!!!NO_REALLY!!!"

# Munki Repo location. This should be in /Users somewhere (not tested lately)
REPOLOC="/Users/Shared"
REPONAME="repo"
MUNKI_REPO="${REPOLOC}/${REPONAME}"
AUTOPKG_RECIPE_LIST="$HOME/Library/AutoPkg/recipe-list.txt"

# HTTP or HTTPS?
# You can direct to https if you like. You would have to have a valid certificate
# already on the server. This is most suited to those of you serving the Munki
# folders via Server.app or a native Nginx/Apache installation.
# If you're running the Docker-Munki container, then this isn't so easy
# to automate. I suggest taking a look at: http://aulin.co/2015/Munki-SSL-Docker/
# and changing the docker run command in run-munki-run.sh.
HTTP_PROTOCOL="http"

# What do you want to call your Munki software manifest?
# site_default will be created, and this manifest will be added as an
# included_manifest
MUNKI_DEFAULT_SOFTWARE_MANIFEST="core_software"

# Preferred text editor
TEXTEDITOR="Atom.app"

# AutoPkg repos
read -r -d '' AUTOPKGREPOS <<ENDMSG
recipes
grahamgilbert-recipes
hjuutilainen-recipes
homebysix-recipes
jleggat-recipes
keeleysam-recipes
killahquam-recipes
scriptingosx-recipes
valdore86-recipes
grahampugh/recipes
ENDMSG

# Comment this line out if you do not want the recipe-list.txt file in this folder to be used
# every time this script is run
cp ./recipe-list.txt $AUTOPKG_RECIPE_LIST


# IP address/host name
# If your Mac has more than one interface, you'll need to change to en0 for wired, en1 if you're running on wifi.
IP=$(ipconfig getifaddr en0)
# Well, let's try en1 if en0 is empty
if [[ -z "$IP" ]]; then
    IP=$(ipconfig getifaddr en1)
fi
# Override this for setups where the Munki host is remote
if [[ "$MUNKI_HOST" ]]; then
    IP=$MUNKI_HOST
fi


### Docker variables for run-munki-run.sh

ADMIN_PASSWORD="run-munki-run"
## Databases location. This should be away from shared directories e.g. the web root.
DBLOC="$HOME/munki-databases"

## Munki container variables:
# Enabled by default. Set to true if you wish to have a Docker Munki server.
# Set to false if you are using something else to serve Munki e.g. Server.app
MUNKI_ENABLED=true
# If MUNKI_ENABLED=false, and/or NOSERVERSETUP=True, you can set a remote address
# for the Munki server here, which will override the $IP variable based on this
# host.
# MUNKI_HOST=123.34.67.89
# Set the public port on which you wish to access Munki
# Note: Docker-Machine with VirtualBox cannot forward ports under 1024
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
MWA2_ENABLED=true
# Create a new folder to house the MWA2 Django database and point to it here:
# If using Docker-Machine, it must be within /Users somewhere:
MWA2_DB="${DBLOC}/mwa2-db"
# Set the public port on which you wish to access MWA2
MWA2_PORT=8003

## Munki-Do settings:
# Disabled by default. Set to true if you wish to use Munki-Do:
MUNKI_DO_ENABLED=false
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
