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

# Munki Repo location. This should be in /Users somewhere (not tested lately)
REPOLOC="/Users/Shared"
REPONAME="repo"
MUNKI_REPO="${REPOLOC}/${REPONAME}"
MUNKI_DEFAULT_SOFTWARE_MANIFEST="core_software"

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
AUTOPKG_RECIPE_LIST="$HOME/Library/AutoPkg/recipe-list.txt"

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

# Autopkg selections
read -r -d '' AUTOPKGRUN <<ENDMSG
AdobeFlashPlayer.munki.recipe
AdobeReader.munki.recipe
AdobeReaderUpdates.munki.recipe
Atom.munki.recipe
Firefox.munki.recipe
GoogleChrome.munki.recipe
osquery.munki.recipe
Sal-osquery.munki.recipe
Sal.munki.recipe
Slack.munki.recipe
munkitools2.munki.recipe
MakeCatalogs.munki.recipe
ENDMSG

# Others
# BBEdit.munki.recipe
# KeePassX.munki.recipe
# Recipe Robot.munki.recipe
# Smultron8.munki.recipe
# SublimeText3.munki.recipe
# Textmate.munki.recipe
# VisualStudioCode.munki.recipe

# AutoPkgr stuff
AUTOPKG_RECIPE_LIST_LOC="$HOME/Library/AutoPkg/RecipeList"

## Docker variables

# Munki container variables:
# Set the public port on which you wish to access Munki
# Note: Docker-Machine with VirtualBox cannot forward ports under 1024
MUNKI_PORT=8000

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

# IP address
# If your Mac has more than one interface, you'll need to change to en0 for wired, en1 if you're running on wifi.
IP=$(ipconfig getifaddr en0)
if [[ -z "$IP" ]]; then
    # Let's try en1 just in case it helps
    IP=$(ipconfig getifaddr en1)
fi

# Proxy Servers - add these if you need to for curl
#HTTP_PROXY=http://proxy.my.company:2010/
#HTTPS_PROXY=$HTTP_PROXY
