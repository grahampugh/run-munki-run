#!/bin/bash

## RUN-MUNKI-RUN SETTINGS
# Read through all these carefully before running this program.

## Munki Repo location. If you are using Docker-Machine, this should be in /Users somewhere
# but if you're using native Docker it doesn't matter.
REPOLOC="/Users/Shared"

## The Munki repo name. If it is set to 'repo' and the hostname is "munki", then you don't need
# to configure 
REPONAME="repo"

# Put it together and you get the path to the repo. No need to change this.
MUNKI_REPO="${REPOLOC}/${REPONAME}"

# IP address - you'll need to change to en0 for wired, en1 if you're running on wifi
# and your Mac has an ethernet port. 
IP=`ipconfig getifaddr en0`

## GIT location. You shouldn't need to alter this.
GIT="/usr/bin/git"

## Sitename:
# If using DNS, put your sitename here, e.g. example.com. Then set your DNS lookup 
# to the sitename, so that e.g. http://munki will redirect to http://munki.example.com
SITENAME="grahamrpugh.com"

## Munki settings:
# If your Munki hostname is munki.[example.com] then you won't need to configure your
# clients to point to this, as Munki looks for http://munki/repo by default
MUNKI_HOSTNAME="munki.$SITENAME"
# Set the public port on which you wish to access Munki 
MUNKI_PORT=8000

## Location for virtual hosts
VIRTUALHOSTSLOC="${REPOLOC}/sites-available"

## Sal settings:
# Create a new folder to house the Sal Django database and point to it here:
# If using Docker-Machine, it must be within /Users somewhere:
SAL_DB="${REPOLOC}/sal-db"
#
# Sal hostname, if you have DNS aliases setup
SAL_HOSTNAME="sal.grahamrpugh.com"
#
# Set the public port on which you wish to access Sal 
SAL_PORT=8001

## MunkiWebAdmin2 settings:
# Create a new folder to house the MWA2 Django database and point to it here:
# If using Docker-Machine, it must be within /Users somewhere:
MWA2_DB="${REPOLOC}/mwa2-db"
#
# MWA2 hostname, if you have DNS aliases setup
MWA2_HOSTNAME="mwa2.grahamrpugh.com"
# Set the public port on which you wish to access MWA2 
MWA2_PORT=8002

## Munki-Do settings:
# Disabled by default. Set to true if you wish to use Munki-Do:
MUNKI_DO_ENABLED=false
# Create a new folder to house the Munki-Do Django database and point to it here.
# If using Docker-Machine, it must be within /Users somewhere:
MUNKI_DO_DB="/Users/Shared/munki-do-db"
# MUNKI_DO hostname, if you have DNS aliases setup
MUNKI_DO_HOSTNAME="munkido.grahamrpugh.com"
# Set the public port on which you wish to access Munki-Do
MUNKI_DO_PORT=8003
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
#
## Manifest Restriction Key:
# Set this key to "restriction" to enable the manifest restriction facility. This allows
# you to restrict access to editing certain manifests by creating and populating groups 
# in the Munki-Do admin interface.
MANIFEST_RESTRICTION_KEY='restriction'
#
## Git path: 
#Comment this out or set to '' to disable git.
# (yeah, it's a bit silly doing it this way. I'll change it to true/false soon, promise)
GIT_PATH=''   ## alternative: GIT_PATH="$GIT"
#
## Git branching:
# Comment this out or leave blank to disable git branching 
# (so all commits are done to master branch).
# Or set to any value, e.g.'yes', 'no', 'fred', in order to enable git branching.
# (does nothing if GIT_PATH is empty)
GIT_BRANCHING=''
#
## Ignore the Pkgs directory:
# Comment this out to enable git to track the 'pkgs' directory
# Or set to any value, e.g.'yes', 'no', 'fred', in order to ignore the pkgs directory
# so that you aren't committing huge files to git..
# (does nothing if GIT_PATH is empty)
GIT_IGNORE_PKGS='yes'
#
## Gitlab (advanced!)
# Note: if you are using the Docker Toolbox (docker-machine), 
# volume linking to /Users won't work in OS X due to a permissions issue, 
# so the volume needs to be linked to a folder in the boot2docker host. 
# You may wish to back this up in case you decide to destroy the docker-machine.
# Comment this out or set as '' if you don't want to build a Gitlab server
# GITLAB_DATA="/home/docker/gitlab-data"
#
## Gitlab ports and secrets:
# (does nothing if GITLAB_DATA is unset)
# Gitlab HTTP port:
GITLAB_PORT=10080
# Gitlab SSH port:
GITLAB_SSH_PORT=10022
# Gitlab Secrets Database Key Base
# Find a way to secure this if you're running in production!
GITLAB_SECRETS_DB_KEY_BASE=sxRfjpqHCfwMBHfrP8NXp5V6gS2wxBLXgv57pdvGKQMQSLTfDzBFfTf2vhQLvrxK
#
# Gitlab PostgreSQL Database variables
DB_NAME=gitlabhq_production
DB_USER=gitlab
DB_PASS=password
## END OF MUNKI DO SETTINGS


### MAC ONLY SETTINGS. If you're on Linux you can ignore all this (and don't run RUN-ME-FIRST)
# Preferred text editor fo AutoPkgr to use. What's your flava?
TEXTEDITOR="TextWrangler.app"
#
## Mac Command locations. No need to change these unless your environment is weird.
MUNKILOC="/usr/local/munki"
MANU="/usr/local/munki/manifestutil"
DEFAULTS="/usr/bin/defaults"
AUTOPKG="/usr/local/bin/autopkg"
AUTOPKGRECIPELISTLOC="$HOME/Library/Application Support/AutoPkgr"
#
## Some other directories you also shouldn't need to change
MAINPREFSDIR="/Library/Preferences"
SCRIPTDIR="/usr/local/bin"
#
## Autopkg selections: 
# Add more recipes here if you wish, but make sure MakeCatalogs is the last one.
read -r -d '' AUTOPKGRUN << ENDMSG
GoogleChrome.munki \
TextWrangler.munki \
munkitools2.munki \
Sal.munki \
Sal-osquery.munki \
MakeCatalogs.munki
ENDMSG
#
## AutoPkgr recipe list:
# These should match the Autopkg selections. Sorry, you'll have to look up the names.
read -r -d '' AUTOPKGRRECIPES << ENDMSG
com.github.autopkg.munki.google-chrome
com.github.autopkg.munki.textwrangler
com.github.grahamgilbert.Sal.munki
com.github.grahamgilbert.Sal-osquery.munki
com.github.autopkg.munki.munkitools2
com.github.autopkg.munki.makecatalogs
ENDMSG
## End of Mac only settings


# logger
LOGGER="/usr/bin/logger -t Run-Munki-Run"

# OS version check
osvers=$(sw_vers -productVersion | awk -F. '{print $2}') # Thanks Rich Trouton

## Docker variables

# Check if this is a Mac
if [[ -d "/Applications/Safari.app" ]]; then
	DOCKERTYPE="none"
	# What type of Docker do we have?
	if [[ -d "/Applications/Docker.app" ]]; then
		DOCKERTYPE="native"
	elif [[ -f "/usr/local/bin/docker-machine" && -d "/Applications/VirtualBox.app" ]]; then
		DOCKERTYPE="docker-machine"
	fi
elif [[ -z "which docker" ]]; then
	DOCKERTYPE="native"
fi
