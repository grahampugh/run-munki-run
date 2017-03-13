#!/bin/bash

# Run-Munki-Run
# by Graham Pugh

# Run-Munki-Run is a Dockerised Munki setup, with extra tools.

# TO DO:
# # Download and install Docker from this script

# This RUN-ME-FIRST script is an adaptation of
# Munki In A Box v.1.4.0
# By Tom Bridge, Technolutionary LLC

# Here is Tom's introduction. I have little to add except: thanks Tom!

# This software carries no guarantees, warranties or other assurances that it works. It may wreck your entire environment. That would be bad, mmkay. Backup, test in a VM, and bug report.

# Approach this script like a swarm of bees: Unless you know what you are doing, keep your distance.

# The goal of this script is to deploy a basic munki repo in a simple script based on a set of common variables. There are default values in these variables, but they are easily overridden and you should decide what they should be.

# This script is based upon the Demonstration Setup Guide for Munki, AutoPkg, and other sources. My sincerest thanks to Greg Neagle, Tim Sutton, Allister Banks, Rich Trouton, Charles Edge, Hannes Juutilainen, Sean Kaiser, Peter Bukowinski, Elliot Jordan, The Linde Group and numerous others who have helped me assemble this script.

# Pre-Reqs for this script: 10.10/Server 4 or 10.11/Server 5.  Web Services should be turned on and PHP should be enabled. This script might work with 10.8 or later, but I'm only testing it on 10.10 or later.

# -------------------------------------------------------------------------------------- #
## Functions

versionCheck() {
    # Check that we are meeting the minimum version
    # Inputs: 1. $osvers

    ${LOGGER} "Starting checks..."

    if [[ $osvers -lt $1 ]]; then
        ${LOGGER} "Could not run because the version of the OS does not meet requirements"
        echo "### Could not run because the version of the OS does not meet requirements."
        echo
        exit 2
    else
        ${LOGGER} "Mac OS X 10.10 or later is installed. Proceeding..."
    fi
}

rootCheck() {
    # Check that the script is NOT running as root
    if [[ $EUID -eq 0 ]]; then
        echo "### This script is NOT MEANT to run as root. This script is meant to be run as an admin user. I'm going to quit now. Run me without the sudo, please."
        echo
        exit 4 # Running as root.
    fi
}

downloadMunki() {
    # Download Munki from github
    # Inputs: 1. $MUNKI_REPO

    MUNKI_LATEST=$(curl https://api.github.com/repos/munki/munki/releases/latest | python -c 'import json,sys;obj=json.load(sys.stdin);print obj["assets"][0]["browser_download_url"]')

    mkdir -p "$1"
    curl -L "${MUNKI_LATEST}" -o "$1/munki-latest.pkg"
}

installMunki() {
    # Install Munki tools on the host Mac
    # Inputs: 1. $MUNKI_REPO

    # Write a Choices XML file for the Munki package. Thanks Rich and Greg!
    /bin/cat > "/tmp/com.github.grahampugh.run-munki-run.munkiinstall.xml" <<MUNKICHOICESDONE
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
    <array>
        <dict>
                <key>attributeSetting</key>
                <integer>1</integer>
                <key>choiceAttribute</key>
                <string>selected</string>
                <key>choiceIdentifier</key>
                <string>core</string>
        </dict>
        <dict>
                <key>attributeSetting</key>
                <integer>1</integer>
                <key>choiceAttribute</key>
                <string>selected</string>
                <key>choiceIdentifier</key>
                <string>admin</string>
        </dict>
        <dict>
                <key>attributeSetting</key>
                <integer>0</integer>
                <key>choiceAttribute</key>
                <string>selected</string>
                <key>choiceIdentifier</key>
                <string>app</string>
        </dict>
        <dict>
                <key>attributeSetting</key>
                <integer>0</integer>
                <key>choiceAttribute</key>
                <string>selected</string>
                <key>choiceIdentifier</key>
                <string>launchd</string>
        </dict>
    </array>
</plist>
MUNKICHOICESDONE

    sudo /usr/sbin/installer -dumplog -verbose -applyChoiceChangesXML "/tmp/com.github.grahampugh.run-munki-run.munkiinstall.xml" -pkg "$1/munki-latest.pkg" -target "/"

    ${LOGGER} "Installed Munki Admin and Munki Core packages"
    echo "### Installed Munki packages"
    echo
}

installCommandLineTools() {
    # Installing the Xcode command line tools on 10.10+
    # This section written by Rich Trouton.
    echo "### Installing the command line tools..."
    echo
    cmd_line_tools_temp_file="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"

    # Installing the latest Xcode command line tools on 10.9.x or 10.10.x

    if [[ "$osx_vers" -ge 9 ]] ; then

        # Create the placeholder file which is checked by the softwareupdate tool
        # before allowing the installation of the Xcode command line tools.
        touch "$cmd_line_tools_temp_file"

        # Find the last listed update in the Software Update feed with "Command Line Tools" in the name
        cmd_line_tools=$(softwareupdate -l | awk '/\*\ Command Line Tools/ { $1=$1;print }' | tail -1 | sed 's/^[[ \t]]*//;s/[[ \t]]*$//;s/*//' | cut -c 2-)

        #Install the command line tools
        sudo softwareupdate -i "$cmd_line_tools" -v

        # Remove the temp file
        if [[ -f "$cmd_line_tools_temp_file" ]]; then
            rm "$cmd_line_tools_temp_file"
        fi
    fi
}

createMunkiRepo() {
    # Creates the Munki repo folders if they don't already exist
    # Inputs: 1. $MUNKI_REPO
    munkiFolderList=( "catalogs" "manifests" "pkgs" "pkgsinfo" "icons" )
    for i in ${munkiFolderList[@]}; do
        mkdir -p "$1/$i"
        echo "### $i folder present and correct!"
    done
    ${LOGGER} "Repo present and correct!"
    echo

    chmod -R a+rX,g+w "$1" ## Thanks Arek!
    chown -R ${USER}:admin "$1" ## Thanks Arek!
    ${LOGGER} "### Repo permissions set"
}

addHTTPBasicAuth() {
    # Adds basic HTTP authentication based on the password set in settings.py
    # Inputs: 1. $MUNKI_REPO
    # Output: $HTPASSWD
    /bin/cat > "$1/.htaccess" <<HTPASSWDDONE
AuthType Basic
AuthName "Munki Repository"
AuthUserFile $1/.htpasswd
Require valid-user
HTPASSWDDONE

    htpasswd -cb $1/.htpasswd munki $HTPASSWD
    HTPASSAUTH=$(python -c "import base64; print \"Authorization: Basic %s\" % base64.b64encode(\"munki:$HTPASSWD\")")
    # Thanks to Mike Lynn for the fix

    sudo chmod 640 $1/.htaccess $1/.htpasswd
    sudo chown _www:wheel $1/.htaccess $1/.htpasswd
    echo $HTPASSWD
    }

createMunkiClientInstaller() {
    # Create a client installer pkg pointing to this repo. Thanks Nick!
    # Inputs:
    # 1. $IP
    # 2. $MUNKI_PORT
    # 3. $REPONAME
    # 4. $MUNKI_REPO
    # 5. installers folder
    # 6. $HTPASSWD
    if [[ ! -f /usr/bin/pkgbuild ]]; then
        ${LOGGER} "Pkgbuild is not installed."
        echo "### Please install command line tools first. Exiting..."
        echo
        exit 0 # Gotta install the command line tools.
    fi

    # Set the SoftwareRepoURL
    mkdir -p "$4/run-munki-run/ClientInstaller/Library/Preferences/"
    ${DEFAULTS} write "$4/run-munki-run/ClientInstaller/Library/Preferences/ManagedInstalls.plist" SoftwareRepoURL "http://$1:$2/$3"
    # Add the HTTP Basic Auth key
    ${DEFAULTS} write /tmp/ClientInstaller/Library/Preferences/ManagedInstalls AdditionalHttpHeaders -array "$6"

    # Add the postinstall script that downloads Munki
    mkdir -p "$4/run-munki-run/scripts"
    cat > "$4/run-munki-run/scripts/postinstall" <<ENDMSG
#!/bin/bash
curl -L "http://$1:$2/$3/installers/munki-latest.pkg" -o "/tmp/munki-latest.pkg"
installer -pkg "/tmp/munki-latest.pkg" -target /
rm /tmp/munki-latest.pkg
ENDMSG
    chmod a+x "$4/run-munki-run/scripts/postinstall"

    # Add restart requirement to install pkg
    cat > "$4/run-munki-run/PackageInfo" <<ENDMSG
<?xml version="1.0" encoding="utf-8" standalone="no"?>
<pkg-info postinstall-action="restart"/>
ENDMSG

    # Build the package
    /usr/bin/pkgbuild --info "$4/run-munki-run/PackageInfo" \
        --identifier com.grahamrpugh.munkiclient.pkg \
        --root "$4/run-munki-run//ClientInstaller" \
        --scripts "$4/run-munki-run/scripts" \
        "$4/$5/ClientInstaller.pkg"

    if [[ -f "$4/$5/ClientInstaller.pkg" ]]; then
        ${LOGGER} "Client install pkg created."
        echo
        echo "### Client install pkg is created. It's in the base of the repo."
        echo
    else
        ${LOGGER} "Client install pkg failed."
        echo
        echo "### Client install pkg failed."
        echo
        exit 2
    fi
}

installAutoPkg() {
    # Get AutoPkg
    # thanks to Nate Felton
    # Inputs: 1. $MUNKI_REPO
    AUTOPKG_LATEST=$(curl https://api.github.com/repos/autopkg/autopkg/releases | python -c 'import json,sys;obj=json.load(sys.stdin);print obj[0]["assets"][0]["browser_download_url"]')
    /usr/bin/curl -L "${AUTOPKG_LATEST}" -o "$1/autopkg-latest.pkg"

    sudo installer -pkg "$1/autopkg-latest.pkg" -target /

    ${LOGGER} "AutoPkg Installed"
    echo
    echo "### AutoPkg Installed"
    echo
}

munkiCreateManifests() {
    # Create Munki manifests
    # Inputs: 1-n. list of manifests to create
    for var in "$@"; do
        ${MANU} new-manifest $var
        echo "### $var manifest created"
    done
    echo
}

munkiMakeCatalogs() {
    # Munki MakeCatalogs command
    echo
    echo "### Running makecatalogs..."
    echo
    /usr/local/munki/makecatalogs
    echo
    echo "### ...done"
    echo
}

munkiAddPackages() {
    # Munki: add packages to manifest.
    # Code adapted from Rich Trouton and Tom Bridge
    # Inputs: 1. $MUNKI_REPO
    existingCatalogs=($(${MANU} list-catalogs))
    listofpkgs="$(${MANU} list-catalog-items ${existingCatalogs[@]})"
    tLen=$(echo "$listofpkgs" | wc -l)
    existingList="$(manifestutil display-manifest "$1" | grep -v :))"
    tLenExisting=$(echo "$existingList" | wc -l)
    if [[ $tLenExisting != $tLen ]]; then
        echo "### $tLen" " packages to install:"
        echo "$listofpkgs"
        echo

        printf '%s\n' "$listofpkgs" | while read -r line; do
            ${LOGGER} "Adding $line to $1"
            optionalInstall=""
            if [[ -z $(echo "$line" | egrep -i 'munki|sal') ]]; then
                optionalInstall="--section optional_installs"
            fi
            ${MANU} add-pkg "$line" --manifest "$1" $optionalInstall
            ${LOGGER} "Added $line to $1"
        done
    fi
}


# -------------------------------------------------------------------------------------- #
## Main section

# Commands
MUNKILOC="/usr/local/munki"
GIT="/usr/bin/git"
MANU="/usr/local/munki/manifestutil"
DEFAULTS="/usr/bin/defaults"
AUTOPKG="/usr/local/bin/autopkg"

# OS version check
osvers=$(sw_vers -productVersion | awk -F. '{print $2}') # Thanks Rich Trouton

# IP address
# If your Mac has more than one interface, you'll need to change to en0 for wired, en1 if you're running on wifi.
IP=$(ipconfig getifaddr en0)
# Well, let's try en1 if en0 is empty
if [[ -z "$IP" ]]; then
    IP=$(ipconfig getifaddr en1)
fi

# logger
LOGGER="/usr/bin/logger -t Run-Munki-Run"

# Establish our Basic Variables:
. settings.sh

# Path to Munki repo
MUNKI_REPO="${REPOLOC}/${REPONAME}"

echo
echo "### Welcome to Run-Munki-Run, a reworking of Tom Bridge's awesome Munki-In-A-Box."
echo "### We're going to get things rolling here with a couple of tests"'!'
echo
echo "### First up: Are you an admin user? Enter your password below:"
echo

#Let's see if this works...
#This isn't bulletproof, but this is a basic test.
sudo whoami > /tmp/quickytest

if [[ $(cat /tmp/quickytest) == "root" ]]; then
    ${LOGGER} "Privilege Escalation Allowed, Please Continue."
else
    ${LOGGER} "Privilege Escalation Denied, User Cannot Sudo."
    echo "### You are not an admin user, you need to do this an admin user."
    exit 1
fi

${LOGGER} "Starting up..."

## Checks

# 10.10+ for the Web Root Location.
versionCheck 10

# Check that the script is NOT running as root
rootCheck

# Let's get the latest Munki Installer
downloadMunki "${MUNKI_REPO}/installers"

# Install Munki if it isn't already there
if [[ ! -f $MUNKILOC/munkiimport ]]; then
    ${LOGGER} "Grabbing and Installing the Munki Tools Because They Aren't Present"
    installMunki "${MUNKI_REPO}/installers"
else
    ${LOGGER} "Munki was already installed, I think, so I'm moving on"
    echo "### Munkitools were already installed"
    echo
fi

# Check for Command line tools.
if [[ ! -f "/usr/bin/git" ]]; then
    installCommandLineTools
fi

echo "### Great. All Tests are passed, so let's create the Munki Repo"'!'
echo
${LOGGER} "All Tests Passed! On to the configuration."


# Create the repo
createMunkiRepo "${MUNKI_REPO}"

# Create a client installer pkg pointing to this repo. Thanks Nick!
HTPASSWD=$(addHTTPBasicAuth "$MUNKI_REPO")
createMunkiClientInstaller "${IP}" "${MUNKI_PORT}" "${REPONAME}" "${MUNKI_REPO}" "installers" "${HTPASSWD}"

# Configure MunkiTools on this computer
${DEFAULTS} write com.googlecode.munki.munkiimport editor "${TEXTEDITOR}"
echo "munkiimport editor set to ${TEXTEDITOR}"
${DEFAULTS} write com.googlecode.munki.munkiimport repo_path "${MUNKI_REPO}"
echo "${MUNKI_REPO} set"
${DEFAULTS} write com.googlecode.munki.munkiimport pkginfo_extension ".plist"
echo "pkginfo_extension set"
${DEFAULTS} write com.googlecode.munki.munkiimport default_catalog "testing"
echo "default_catalog set"
plutil -convert xml1 ~/Library/Preferences/com.googlecode.munki.munkiimport.plist

# Get AutoPkg
# Nod and Toast to Nate Felton!
if [[ ! -d ${AUTOPKG} ]]; then
    installAutoPkg "${MUNKI_REPO}"
fi

# Configure AutoPkg for use with Munki and Sal
if [[ $(${DEFAULTS} read com.github.autopkg MUNKI_REPO) != "${MUNKI_REPO}" ]]; then
    ${DEFAULTS} write com.github.autopkg MUNKI_REPO "${MUNKI_REPO}"
    echo "${MUNKI_REPO} set in AutoPkg"
fi

# Check if there is already an AutoPkg recipe list.
# If so we can skip running AutoPkg here as it has already been done in the past
if [[ ! -f "${AUTOPKG_RECIPE_LIST}" ]]; then
    # Add AutoPkg recipes
    ${AUTOPKG} repo-add ${AUTOPKGREPOS}
    ${LOGGER} "AutoPkg Configured"
    echo
    echo "### AutoPkg Configured"

    # make recipe overrides for some packages
    printf '%s\n' "${AUTOPKGRUN}" | while read -r line; do
        ${AUTOPKG} make-override "$line"
    done
    echo

    # Create a recipe list file so it's easy to run in the future
    echo "${AUTOPKGRUN}" >> "${AUTOPKG_RECIPE_LIST}"
fi

# Run the AutoPkg recipe list
${AUTOPKG} run --recipe-list="${AUTOPKG_RECIPE_LIST}"

${LOGGER} "AutoPkg has Run"
echo
echo "### AutoPkg has run"
echo

# Create new site_default and core_software manifests (nothing happens if they already exist)
munkiCreateManifests site_default $MUNKI_DEFAULT_SOFTWARE_MANIFEST

# Test whether there are already catalogs in the site_default manifest
if [[ $(echo "$(${MANU} display-manifest site_default)" | grep -A1 catalogs: | grep -v catalogs: | grep :) ]]; then
    # no catalogs found, let's add them
    # the order is important! The second item takes priority
    ${MANU} add-catalog production --manifest site_default
    ${MANU} add-catalog testing --manifest site_default
    echo "### testing and production catalogs added to site_default"
else
    echo "### Catalogs already present in site_default. Moving on..."
fi
echo

# Add the core_software manifest as an included manifest (nothing happens if if already added)
${MANU} add-included-manifest "$MUNKI_DEFAULT_SOFTWARE_MANIFEST" --manifest site_default
echo "### $MUNKI_DEFAULT_SOFTWARE_MANIFEST manifest added to as an included manifest to Site_Default"
echo

# Add packages to software manifest
munkiAddPackages $MUNKI_DEFAULT_SOFTWARE_MANIFEST

# Generate icons for the added packages using Munki's iconimporter command
echo "### Generating icons for the added packages using Munki's iconimporter command"
iconimporter

# Let's makecatalogs just in case
munkiMakeCatalogs

# Clean Up When Done
rm "$MUNKI_REPO/autopkg-latest.pkg"
rm -rf "$MUNKI_REPO/run-munki-run"
rm /tmp/quickytest

${LOGGER} "All done."

echo
echo "### You should now have a populated repo at $MUNKI_REPO!"
echo

# This autoruns the second script, if it's there!
if [[ -f "run-munki-run.sh" && $NOSERVERSETUP != True ]]; then
    echo "### Now let's start the Munki server..."
    . run-munki-run.sh mac
fi

exit 0
