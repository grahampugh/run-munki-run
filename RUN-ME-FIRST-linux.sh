#!/bin/bash

# Run-Munki-Run
# by Graham Pugh

# Run-Munki-Run is a Dockerised Munki setup, with extra tools.

# This Linux setup script will set up the server and basic tools. You need a Mac to manipulate the manifests and run AutoPkg.

# TO DO:
# # Download and install Docker from this script


# -------------------------------------------------------------------------------------- #
## Functions

# Check that the script is NOT running as root
rootCheck() {
    if [[ $EUID -eq 0 ]]; then
        echo "### This script is NOT MEANT to run as root. This script is meant to be run as an admin user. I'm going to quit now. Run me without the sudo, please."
        echo
        exit 4 # Running as root.
    fi
}

downloadMunki() {
    MUNKI_LATEST=$(curl https://api.github.com/repos/munki/munki/releases/latest | python -c 'import json,sys;obj=json.load(sys.stdin);print obj["assets"][0]["browser_download_url"]')

    mkdir -p "$1"
    curl -L "${MUNKI_LATEST}" -o "$1/munki-latest.pkg"
}

installMunki() {
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

    sudo /usr/sbin/installer -dumplog -verbose -applyChoiceChangesXML "/tmp/com.github.grahampugh.run-munki-run.munkiinstall.xml" -pkg "$1/munki-latest.pkg" -target "/"

    ${LOGGER} "Installed Munki Admin and Munki Core packages"
    echo "### Installed Munki packages"
    echo
}

createMunkiRepo() {
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


# -------------------------------------------------------------------------------------- #
## Main section

# Establish our Basic Variables:
. settings.sh

# Set proxy if populated
if [[ -z $HTTP_PROXY ]]; then
    export http_proxy=$HTTP_PROXY
fi
if [[ -z $HTTPS_PROXY ]]; then
    export https_proxy=$HTTPS_PROXY
fi


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

# Let's makecatalogs just in case
munkiMakeCatalogs

${LOGGER} "All done."

echo
echo "### You should now have a populated repo!"
echo "### Now let's start the Munki server..."
echo

# This autoruns the second script, if it's there!
if [[ -f "run-munki-run.sh" ]]; then
    . run-munki-run.sh linux
fi

exit 0
