#!/bin/bash

# logger
LOGGER="/usr/bin/logger -t Run-Munki-Run"

# IP address - you'll need to change to en0 for wired, en1 if you're running on wifi.
IP=`ipconfig getifaddr en0`

# Munki Repo location. This should be in /Users somewhere (not tested lately)
REPOLOC="/Users/Shared"
REPONAME="repo"
MUNKI_REPO="${REPOLOC}/${REPONAME}"

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

# Autopkg selections
read -r -d '' AUTOPKGRUN << ENDMSG
GoogleChrome.munki \
TextWrangler.munki \
munkitools2.munki \
Sal.munki \
Sal-osquery.munki \
MakeCatalogs.munki
ENDMSG

# AutoPkgr stuff
AUTOPKGRECIPELISTLOC="$HOME/Library/Application Support/AutoPkgr"

# These should match the Autopkg selections. Sorry, you'll have to look up the names.
read -r -d '' AUTOPKGRRECIPES << ENDMSG
com.github.autopkg.munki.google-chrome
com.github.autopkg.munki.textwrangler
com.github.grahamgilbert.Sal.munki
com.github.grahamgilbert.Sal-osquery.munki
com.github.autopkg.munki.munkitools2
com.github.autopkg.munki.makecatalogs
ENDMSG

## Docker variables

# Munki container variables
# If you have access to DNS, use the Apache container to proxy each Docker web service
# to a hostname. I recommend "munki" for the Munki host so you don't need to set a 
# preference.
MUNKI_HOSTNAME="munki.grahamrpugh.com"
# Set the public port on which you wish to access Munki 
MUNKI_PORT=8000

# Location for virtual hosts
VIRTUALHOSTSLOC="${REPOLOC}/sites-available"

# Create a new folder to house the Sal Django database and point to it here:
# If using Docker-Machine, it must be within /Users somewhere:
SAL_DB="${REPOLOC}/sal-db"
# Sal hostname, if you have DNS aliases setup
SAL_HOSTNAME="sal.grahamrpugh.com"
# Set the public port on which you wish to access Sal 
SAL_PORT=8001
# Create a new folder to house the MWA2 Django database and point to it here:
# If using Docker-Machine, it must be within /Users somewhere:
MWA2_DB="${REPOLOC}/mwa2-db"
# MWA2 hostname, if you have DNS aliases setup
MWA2_HOSTNAME="mwa2.grahamrpugh.com"
# Set the public port on which you wish to access MWA2 
MWA2_PORT=8002
