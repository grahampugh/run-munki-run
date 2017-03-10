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

# Check that we are meeting the minimum version
versionCheck() {
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

# Check that the script is NOT running as root
rootCheck() {
    if [[ $EUID -eq 0 ]]; then
        echo "### This script is NOT MEANT to run as root. This script is meant to be run as an admin user. I'm going to quit now. Run me without the sudo, please."
        echo
        exit 4 # Running as root.
    fi
}

installMunki() {
    MUNKI_LATEST=$(curl https://api.github.com/repos/munki/munki/releases/latest | python -c 'import json,sys;obj=json.load(sys.stdin);print obj["assets"][0]["browser_download_url"]')
    
    curl -L "${MUNKI_LATEST}" -o "$1/munki-latest.pkg"
    
    # Write a Choices XML file for the Munki package. Thanks Rich and Greg!

    /bin/cat > "/tmp/com.github.grahampugh.run-munki-run.munkiinstall.xml" << 'MUNKICHOICESDONE'
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

    sudo /usr/sbin/installer -dumplog -verbose -applyChoiceChangesXML "/tmp/com.github.grahampugh.run-munki-run.munkiinstall.xml" -pkg "${MUNKI_REPO}/munki-latest.pkg" -target "/"

    ${LOGGER} "Installed Munki Admin and Munki Core packages"
    echo "### Installed Munki packages"
    echo
}


# Installing the Xcode command line tools on 10.10+
# This section written by Rich Trouton.
installCommandLineTools() {
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
    if [[ ! -d "$1" ]]; then
        mkdir -p "$1/catalogs"
        mkdir -p "$1/manifests"
        mkdir -p "$1/pkgs"
        mkdir -p "$1/pkgsinfo"
        mkdir -p "$1/icons"
        ${LOGGER} "Repo Created"
        echo "### Repo Created"
        echo
    fi

    chmod -R a+rX,g+w "$1" ## Thanks Arek!
    chown -R ${USER}:admin "$1" ## Thanks Arek!

    ${LOGGER} "### Repo permissions set"
}

# Create a client installer pkg pointing to this repo. Thanks Nick!
createMunkiClientInstaller() {
    if [[ ! -f /usr/bin/pkgbuild ]]; then
        ${LOGGER} "Pkgbuild is not installed."
        echo "### Please install command line tools first. Exiting..."
        echo 
        exit 0 # Gotta install the command line tools.
    fi

    mkdir -p /tmp/ClientInstaller/Library/Preferences/

    ${DEFAULTS} write /tmp/ClientInstaller/Library/Preferences/ManagedInstalls.plist SoftwareRepoURL "http://$1:$2/$3"

    /usr/bin/pkgbuild --identifier com.grahamrpugh.munkiclient.pkg --root /tmp/ClientInstaller "$4/ClientInstaller.pkg"
    ${LOGGER} "Client install pkg created."
    echo
    echo "### Client install pkg is created. It's in the base of the repo."
    echo
}

# Get AutoPkg
# Nod and Toast to Nate Felton!
installAutoPkg() {
    AUTOPKG_LATEST=$(curl https://api.github.com/repos/autopkg/autopkg/releases | python -c 'import json,sys;obj=json.load(sys.stdin);print obj[0]["assets"][0]["browser_download_url"]')
    /usr/bin/curl -L "${AUTOPKG_LATEST}" -o "$1/autopkg-latest.pkg"

    sudo installer -pkg "$1/autopkg-latest.pkg" -target /

    ${LOGGER} "AutoPkg Installed"
    echo
    echo "### AutoPkg Installed"
    echo
}

# Create Munki manifests
munkiCreateManifests() {
    for var in "$@"; do
        ${MANU} new-manifest $var
        echo "### $var manifest created"
    done
    echo
}

# Munki MakeCatalogs command
munkiMakeCatalogs() {
    echo
    echo "### Running makecatalogs..."
    echo
    /usr/local/munki/makecatalogs
    echo
    echo "### ...done"
    echo
}

# Munki add packages to manifest
munkiAddPackages() {
    # Code for Array Processing borrowed from First Boot Packager. Thanks Rich! 
    listofpkgs=($(${MANU} list-catalog-items testing development production))
    tLen=${#listofpkgs[@]}
    existingList=($(manifestutil display-manifest $1 | grep :))
    tLenExisting=${#existingList[@]}
    if [[ $tLenExisting != $tLen ]]; then
        echo "### $tLen" " packages to install"
        echo "${listofpkgs[*]}"
        echo

        for (( i=0; i<tLen; i++ )); do
            ${LOGGER} "Adding ${listofpkgs[$i]} to $1"
            optionalInstall=""
            if [[ -z $(echo "${listofpkgs[$i]}" | egrep -i 'munki|sal') ]]; then
                optionalInstall="--section optional_installs"
            fi
            ${MANU} add-pkg ${listofpkgs[$i]} --manifest "$1" $optionalInstall
            ${LOGGER} "Added ${listofpkgs[$i]} to $1"
        done
    fi
}

# -------------------------------------------------------------------------------------- #
## Main section

# Establish our Basic Variables:
. settings.sh

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

####
# Checks
####


# 10.10+ for the Web Root Location.
versionCheck 10

# Check that the script is NOT running as root
rootCheck

# Install Munki if it isn't already there
if [[ ! -f $MUNKILOC/munkiimport ]]; then
    ${LOGGER} "Grabbing and Installing the Munki Tools Because They Aren't Present"
    installMunki "${MUNKI_REPO}"
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
createMunkiClientInstaller "${IP}" "${MUNKI_PORT}" "${REPONAME}" "${MUNKI_REPO}"

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
    ${AUTOPKG} run --recipe-list="${AUTOPKG_RECIPE_LIST}"

    ${LOGGER} "AutoPkg has Run"
    echo
    echo "### AutoPkg has run"
    echo 
fi

# Check for existing manifests, create them if not there, but don't mess with existing setup
if [[ -z $(${MANU} list-manifests) ]]; then
    # Create new site_default and core_software manifests
    munkiCreateManifests site_default $MUNKI_DEFAULT_SOFTWARE_MANIFEST
    
    # Add the testing catalog to site_default
    ${MANU} add-catalog testing --manifest site_default
    echo "### Testing Catalog added to Site_Default"
    echo

    # Add the core_software manifest as an included manifest
    ${MANU} add-included-manifest "$MUNKI_DEFAULT_SOFTWARE_MANIFEST" --manifest site_default
    echo "### $MUNKI_DEFAULT_SOFTWARE_MANIFEST manifest added to as an included manifest to Site_Default"
    echo

    # Add packages to software manifest
    munkiAddPackages $MUNKI_DEFAULT_SOFTWARE_MANIFEST
fi

# Let's makecatalogs just in case
munkiMakeCatalogs

# Clean Up When Done
rm "$MUNKI_REPO/autopkg-latest.pkg"
rm -rf /tmp/ClientInstaller
# rm "$MUNKI_REPO/munki-latest.pkg"  # let's keep this available for download by clients

${LOGGER} "All done."

echo 
echo "### You should now have a populated repo."
echo
echo "### To update Autopkg recipes in the future, run the following command:"
echo "### autopkg run --recipelist \"${AUTOPKG_RECIPE_LIST}\""
echo 
echo "### Now let's start the Munki server..."
echo

# This autoruns the second script, if it's there!
if [[ -f "run-munki-run.sh" ]]; then
    . run-munki-run.sh
fi

exit 0