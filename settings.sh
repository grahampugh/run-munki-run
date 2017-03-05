#!/bin/bash

# Munki Repo location. This should be in /Users somewhere (not tested lately)
REPOLOC="/Users/Shared"
REPONAME="repo"
MUNKI_REPO="${REPOLOC}/${REPONAME}"

# Databases location. This should be away from shared directories e.g. the web root.
DBLOC="$HOME/munki-databases"

# Commands
MUNKILOC="/usr/local/munki"
GIT="/usr/bin/git"
MANU="/usr/local/munki/manifestutil"
DEFAULTS="/usr/bin/defaults"
AUTOPKG="/usr/local/bin/autopkg"

# Preferred text editor
TEXTEDITOR="TextWrangler.app"

# OS version check
osvers=$(sw_vers -productVersion | awk -F. '{print $2}') # Thanks Rich Trouton

# Some other directories
MAINPREFSDIR="/Library/Preferences"
SCRIPTDIR="/usr/local/bin"

# Autopkg selections
read -r -d '' AUTOPKGRUN << ENDMSG
GoogleChrome.munki \
TextWrangler.munki \
munkitools2.munki \
Sal.munki \
MakeCatalogs.munki
ENDMSG

# AutoPkgr stuff
AUTOPKGRECIPELISTLOC="$HOME/Library/Application Support/AutoPkgr"

# These should match the Autopkg selections. Sorry, you'll have to look up the names.
read -r -d '' AUTOPKGRRECIPES << ENDMSG
com.github.autopkg.munki.google-chrome
com.github.autopkg.munki.textwrangler
com.github.grahamgilbert.Sal.munki
com.github.autopkg.munki.munkitools2
com.github.autopkg.munki.makecatalogs
ENDMSG

## Docker variables

# Munki container variables:
MUNKI_HOSTNAME="munki.grahamrpugh.com"
# Set the public port on which you wish to access Munki 
MUNKI_PORT=80

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

# IP address - you'll need to change to en0 for wired, en1 if you're running on wifi.
IP=$(ipconfig getifaddr en0)


