#!/bin/bash

# Run-Munki-Run
# by Graham Pugh

# Run-Munki-Run is a Dockerised Munki setup, with extra tools.

# TO DO:
# # Download and install Docker from this script

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
    # Inputs: 1. $system_version_major

    # determine the OS version if macOS
    system_version=$( /usr/bin/sw_vers -productVersion )
    system_os=$(cut -d. -f 1 <<< "$system_version")
    if [[ $system_os -eq 10 ]]; then
        system_version_major=$(cut -d. -f1,2 <<< "$system_version")
    else
        system_version_major=$(cut -d. -f1 <<< "$system_version")
    fi
    ${LOGGER} "System Version: $system_version_major"
    echo "### System Version: $system_version_major"
    echo

    ${LOGGER} "Starting checks..."
    echo "### Starting checks..."

    if [[ $(echo "$system_version_major < 10.10" | bc) == 1 ]]; then
        ${LOGGER} "Could not run because the version of the OS does not meet requirements"
        echo "### Could not run because the version of the OS does not meet requirements."
        echo
        exit 2
    else
        ${LOGGER} "Mac OS X 10.10 or later is installed. Proceeding..."
        echo "### Mac OS X 10.10 or later is installed. Proceeding..."
        echo
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
    ${LOGGER} "Downloading Munki..."
    echo "### Downloading Munki..."

    MUNKI_LATEST=$(curl https://api.github.com/repos/munki/munki/releases/latest | python3 -c 'import json,sys;obj=json.load(sys.stdin);print(obj["assets"][0]["browser_download_url"])')

    ${LOGGER} "Creating $1..."
    echo "### Creating $1..."
    mkdir -p "$1"
    curl -L "${MUNKI_LATEST}" -o "$1/munki-latest.pkg"
    echo
}

installMunki() {
    # Install Munki tools on the host Mac
    # Inputs: 1. $MUNKI_REPO

    # Write a Choices XML file for the Munki package. Thanks Rich and Greg!
    /bin/cat > "/tmp/com.github.grahampugh.run-munki-run.munkiinstall.xml" <<MUNKICHOICES
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
MUNKICHOICES

    sudo /usr/sbin/installer -dumplog -verbose -applyChoiceChangesXML "/tmp/com.github.grahampugh.run-munki-run.munkiinstall.xml" -pkg "$1/munki-latest.pkg" -target "/"

    ${LOGGER} "Installed Munki Admin and Munki Core packages"
    echo "### Installed Munki packages"
    echo
}

installCommandLineTools() {
    # Installing the Xcode command line tools on 10.10+
    # This section written by Rich Trouton.
    echo "   [setup] Installing the command line tools..."
    echo
    zsh ./XcodeCLTools-install.zsh
}

createCertificates() {
    # creates a Certificate Authority root
    # From https://mpolinowski.github.io/docs/DevOps/NGINX/2020-08-27--nginx-docker-ssl-certs-self-signed/2020-08-27/
    # Inputs: 1. $CA_NAME

    # mkdirs
    MUNKICONFIGDIR="/Users/Shared/munki-config"
    SSLDIR="$MUNKICONFIGDIR/ssl"
    mkdir -p "$SSLDIR" "$MUNKICONFIGDIR/conf.d"

    # Create a Certificate Authority root
    openssl genrsa -aes256 -out "$SSLDIR/ca.key" 4096
    openssl req -new -x509 -nodes -days 1826 \
        -key "$SSLDIR/ca.key" \
        -out "$SSLDIR/ca.crt" \
        -subj "/CN=$IP/C=$CA_COUNTRY/ST=$CA_STATE/L=$CA_LOCALE/O=$CA_ORG"

    # Create the Client Key and CSR
    openssl genrsa -aes256 -out "$SSLDIR/client.key" 4096
    openssl req -new \
        -key "$SSLDIR/client.key" \
        -out "$SSLDIR/client.csr" \
        -subj "/CN=$IP/C=$CA_COUNTRY/ST=$CA_STATE/L=$CA_LOCALE/O=$CA_ORG"

    # Self-sign Client crt
    openssl x509 -req -days 1826 \
        -in "$SSLDIR/client.csr" \
        -CA "$SSLDIR/ca.crt" \
        -CAkey "$SSLDIR/ca.key" \
        -set_serial 01 \
        -out "client.crt"

    # Convert Client Key and crt to PEM
    openssl x509 \
        -in "$SSLDIR/client.crt" \
        -out "$SSLDIR/client-munki.crt.pem" \
        -outform PEM
    openssl rsa \
        -in "$SSLDIR/client.key" \
        -out "$SSLDIR/client-munki.key.pem" \
        -outform PEM
    
    # Create the Server Key and CRT
    openssl genrsa -aes256 -out "$SSLDIR/nginx-selfsigned.key" 4096
    openssl req -new -x509 -nodes -days 1826 \
        -key "$SSLDIR/nginx-selfsigned.key" \
        -out "$SSLDIR/nginx-selfsigned.crt" \
        -subj "/CN=$IP/C=$CA_COUNTRY/ST=$CA_STATE/L=$CA_LOCALE/O=$CA_ORG"
    openssl dhparam -out "$SSLDIR/dhparam.pem" 4096

    # now create an nginx conf.d file
    /bin/cat "$MUNKICONFIGDIR/conf.d/self-signed.conf" << CONFFILE
ssl_certificate /etc/nginx/ssl/nginx-selfsigned.crt;
ssl_certificate_key /etc/nginx/ssl/nginx-selfsigned.key;
CONFFILE

    /bin/cat "$MUNKICONFIGDIR/conf.d/ssl-params.conf" << CONFFILE
ssl_protocols TLSv1.2;
ssl_prefer_server_ciphers on;
ssl_dhparam /etc/nginx/ssl/dhparam.pem;
ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384;
ssl_ecdh_curve secp384r1; # Requires nginx >= 1.1.0
ssl_session_timeout  10m;
ssl_session_cache shared:SSL:10m;
ssl_session_tickets off; # Requires nginx >= 1.5.9
ssl_stapling on; # Requires nginx >= 1.3.7
ssl_stapling_verify on; # Requires nginx => 1.3.7
resolver 8.8.8.8 8.8.4.4 valid=300s;
resolver_timeout 5s;
# Disable strict transport security for now. You can uncomment the following
# line if you understand the implications.
# add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload";
add_header X-Frame-Options DENY;
add_header X-Content-Type-Options nosniff;
add_header X-XSS-Protection "1; mode=block";
CONFFILE

}

createMunkiRepo() {
    # Creates the Munki repo folders if they don't already exist
    # Inputs: 1. $MUNKI_REPO
    munkiFolderList=( "catalogs" "manifests" "pkgs" "pkgsinfo" "icons" )
    for i in "${munkiFolderList[@]}"; do
        mkdir -p "$1/$i"
        echo "### $i folder present and correct!"
    done
    ${LOGGER} "Repo present and correct!"
    echo

    chmod -R a+rX,g+w "$1" ## Thanks Arek!
    chown -R "${USER}:admin" "$1" ## Thanks Arek!
    ${LOGGER} "### Repo permissions set"
}

addHTTPBasicAuth() {
    # Adds basic HTTP authentication based on the password set in settings.sh
    # Inputs:
    # 1. $MUNKI_REPO
    # 2. $HTPASSWD
    # Output: $HTPASSWD
    sudo rm -f "$1/.htaccess"
    sudo rm -f "$1/.htpasswd"
    /bin/cat > "$1/.htaccess" <<HTPASSWD
AuthType Basic
AuthName "Munki Repository"
AuthUserFile $1/.htpasswd
Require valid-user
HTPASSWD

    htpasswd -cb "$1/.htpasswd" munki $2
    HTPASSAUTH=$(python3 -c "import base64; print(\"Authorization: Basic %s\" % base64.b64encode(bytes(\"munki:$2\", 'utf-8')))")
    # Thanks to Mike Lynn for the fix

    #sudo chmod 640 "$1/.htaccess" "$1/.htpasswd"
    #sudo chown _www:wheel "$1/.htaccess" "$1/.htpasswd"
    echo "$HTPASSAUTH"
    }

createMunkiClientInstaller() {
    # Create a client installer pkg pointing to this repo. Thanks Nick!
    # Inputs:
    # 1. $IP
    # 2. $MUNKI_PORT
    # 3. $REPONAME
    # 4. $MUNKI_REPO
    # 5. installers folder
    # 6. $HTPASSAUTH
    if [[ ! -f /usr/bin/pkgbuild ]]; then
        ${LOGGER} "Pkgbuild is not installed."
        echo "### Please install command line tools first. Exiting..."
        echo
        exit 0 # Gotta install the command line tools.
    fi

    # Set the SoftwareRepoURL
    mkdir -p "$4/run-munki-run/ClientInstaller/Library/Preferences"
    ${DEFAULTS} write "$4/run-munki-run/ClientInstaller/Library/Preferences/ManagedInstalls.plist" SoftwareRepoURL "$HTTP_PROTOCOL://$1:$2/$3"
    # Add the HTTP Basic Auth key
    mkdir -p "$4/run-munki-run/ClientInstaller/private/var/root/Library/Preferences"
    ${DEFAULTS} write "$4/run-munki-run/ClientInstaller/private/var/root/Library/Preferences/ManagedInstalls.plist" AdditionalHttpHeaders -array "$6"

    # Add the postinstall script that downloads Munki
    mkdir -p "$4/run-munki-run/scripts"
    cat > "$4/run-munki-run/scripts/postinstall" <<ENDMSG
#!/bin/bash
curl -L "$HTTP_PROTOCOL://$1:$2/$3/installers/munki-latest.pkg" -o "/tmp/munki-latest.pkg"
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
        --root "$4/run-munki-run/ClientInstaller" \
        --scripts "$4/run-munki-run/scripts" \
        "$4/$5/ClientInstaller.pkg"

    if [[ -f "$4/$5/ClientInstaller.pkg" ]]; then
        ${LOGGER} "Client install pkg created."
        echo
        echo "### Client install pkg is created."
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
    # Inputs: 1. $USERHOME
    if [[ $use_beta == "yes" ]]; then
        AUTOPKG_LATEST=$(curl https://api.github.com/repos/autopkg/autopkg/releases | python3 -c 'import json,sys;obj=json.load(sys.stdin);print(obj[0]["assets"][0]["browser_download_url"])')
    else
        AUTOPKG_LATEST=$(curl https://api.github.com/repos/autopkg/autopkg/releases/latest | python3 -c 'import json,sys;obj=json.load(sys.stdin);print(obj["assets"][0]["browser_download_url"])')
    fi
    /usr/bin/curl -L "${AUTOPKG_LATEST}" -o "$1/autopkg-latest.pkg"

    sudo installer -pkg "$1/autopkg-latest.pkg" -target /

    autopkg_version=$(${AUTOPKG} version)

    ${LOGGER} "AutoPkg $autopkg_version Installed"
    echo
    echo "### AutoPkg $autopkg_version Installed"
    echo

    # Clean Up When Done
    rm "$1/autopkg-latest.pkg"
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
    listofpkgs="$(${MANU} list-catalog-items "${existingCatalogs[@]}")"
    tLen=$(echo "$listofpkgs" | wc -l)
    existingList="$(${MANU} display-manifest "$1" | grep -v :))"
    tLenExisting=$(echo "$existingList" | wc -l)
    if [[ $tLenExisting != $tLen ]]; then
        echo "### $tLen" " packages to install:"
        echo "$listofpkgs"
        echo

        printf '%s\n' "$listofpkgs" | while read -r line; do
            ${LOGGER} "Adding $line to $1"
            optionalInstall=""
            if [[ -z $(echo "$line" | egrep -i 'munkitools|sal|osquery') ]]; then
                optionalInstall="--section optional_installs"
            fi
            ${MANU} add-pkg "$line" --manifest "$1" $optionalInstall
            ${LOGGER} "Added $line to $1"
        done
    fi
}


# -------------------------------------------------------------------------------------- #
## Main section

# Commands
MUNKILOC="/usr/local/munki"
GIT="/usr/bin/git"
MANU="/usr/local/munki/manifestutil"
DEFAULTS="/usr/bin/defaults"
AUTOPKG="/usr/local/bin/autopkg"

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

# Let's see if this works...
# This isn't bulletproof, but this is a basic test.
sudo whoami > /tmp/quickytest

if [[ $(cat /tmp/quickytest) == "root" ]]; then
    ${LOGGER} "Privilege Escalation Allowed, Please Continue."
else
    ${LOGGER} "Privilege Escalation Denied, User Cannot Sudo."
    echo "### You are not an admin user, you need to do this an admin user."
    echo
    exit 1
fi

${LOGGER} "Starting up..."

## Checks

# 10.10+ for the Web Root Location.
versionCheck

# Check that the script is NOT running as root
rootCheck

# Check for Command line tools which are required for python3.
if ! xcode-select -p >/dev/null 2>&1 ; then
    installCommandLineTools
fi

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

echo "### Great. All Tests are passed, so let's create the Munki Repo"'!'
echo
${LOGGER} "All Tests Passed! On to the configuration."


# Create the repo
createMunkiRepo "${MUNKI_REPO}"

# generate certificates
if [[ $GENERATE_CERTIFICATES ]]; then
    createCertificates
fi

# Create a client installer pkg pointing to this repo. Thanks Nick!
HTPASSAUTH=$(addHTTPBasicAuth "$MUNKI_REPO" "$HTPASSWD")
createMunkiClientInstaller "${IP}" "${MUNKI_PORT}" "${REPONAME}" "${MUNKI_REPO}" "installers" "${HTPASSAUTH}"

echo "### If you are testing and don't want to reinstall Munkitools on your client,"
echo "### run the following commands on the client instead:"
echo
echo "sudo defaults write /Library/Preferences/ManagedInstalls.plist SoftwareRepoURL \"$HTTP_PROTOCOL://$IP:$MUNKI_PORT/$REPONAME\""
echo "sudo defaults write /private/var/root/Library/Preferences/ManagedInstalls.plist AdditionalHttpHeaders -array \"$HTPASSAUTH\""
echo

# Configure MunkiTools on this computer
${DEFAULTS} write com.googlecode.munki.munkiimport editor "${TEXTEDITOR}"
echo "### munkiimport editor set to ${TEXTEDITOR}"
${DEFAULTS} write com.googlecode.munki.munkiimport repo_path "${MUNKI_REPO}"
echo "### ${MUNKI_REPO} set"
${DEFAULTS} write com.googlecode.munki.munkiimport pkginfo_extension ".plist"
echo "### pkginfo_extension set"
${DEFAULTS} write com.googlecode.munki.munkiimport default_catalog "testing"
echo "### default catalog set to testing"
plutil -convert xml1 ~/Library/Preferences/com.googlecode.munki.munkiimport.plist
echo

# Get AutoPkg
# Nod and Toast to Nate Felton!
if [[ ! -d ${AUTOPKG} ]]; then
    installAutoPkg "${MUNKI_REPO}"
fi

# read the supplied prefs file or else use the default
AUTOPKG_PREFS="$HOME/Library/Preferences/com.github.autopkg.plist"

# add the GIT path to the prefs
${DEFAULTS} write "$AUTOPKG_PREFS" GIT_PATH "$(which git)"
echo "### Wrote GIT_PATH $(which git) to $AUTOPKG_PREFS"

# add the GitHub token to the prefs
if [[ $GITHUB_TOKEN ]]; then
    GITHUB_TOKEN_PATH="$HOME/Library/AutoPkg/gh_token"
    echo "$GITHUB_TOKEN" > "$GITHUB_TOKEN_PATH"
    echo "### Wrote GITHUB_TOKEN to $GITHUB_TOKEN_PATH"
    ${DEFAULTS} write "${AUTOPKG_PREFS}" GITHUB_TOKEN_PATH "$GITHUB_TOKEN_PATH"
    echo "### Wrote GITHUB_TOKEN_PATH to $AUTOPKG_PREFS"
fi

# ensure untrusted recipes fail
if [[ $fail_recipes == "no" ]]; then
    ${DEFAULTS} write "$AUTOPKG_PREFS" FAIL_RECIPES_WITHOUT_TRUST_INFO -bool false
    echo "### Wrote FAIL_RECIPES_WITHOUT_TRUST_INFO false to $AUTOPKG_PREFS"
else
    ${DEFAULTS} write "$AUTOPKG_PREFS" FAIL_RECIPES_WITHOUT_TRUST_INFO -bool true
    echo "### Wrote FAIL_RECIPES_WITHOUT_TRUST_INFO true to $AUTOPKG_PREFS"
fi

# Configure AutoPkg for use with Munki and Sal
if [[ $(${DEFAULTS} read "$AUTOPKG_PREFS" MUNKI_REPO) != "${MUNKI_REPO}" ]]; then
    ${DEFAULTS} write "$AUTOPKG_PREFS" MUNKI_REPO "${MUNKI_REPO}"
    echo "### Setting ${MUNKI_REPO} in AutoPkg"
else
    echo "### ${MUNKI_REPO} set in AutoPkg"
fi

# ensure we have the recipe list dictionary and array
if ! ${DEFAULTS} read "$AUTOPKG_PREFS" RECIPE_SEARCH_DIRS 2>/dev/null; then
    ${DEFAULTS} write "$AUTOPKG_PREFS" RECIPE_SEARCH_DIRS -array
fi
if ! ${DEFAULTS} read "$AUTOPKG_PREFS" RECIPE_REPOS 2>/dev/null; then
    ${DEFAULTS} write "$AUTOPKG_PREFS" RECIPE_REPOS -dict
fi

# build the repo list
AUTOPKG_REPOS=()
while IFS= read -r; do
    repo="$REPLY"
    AUTOPKG_REPOS+=("$repo")
done <<< "$AUTOPKGREPOS"

# Add AutoPkg repos (checks if already added)
for r in "${AUTOPKG_REPOS[@]}"; do
    if ${AUTOPKG} repo-add "$r" 2>/dev/null; then
        echo "Added $r to $AUTOPKG_PREFS"
    else
        echo "ERROR: could not add $r to $AUTOPKG_PREFS"
    fi
done

${LOGGER} "AutoPkg Repos Configured"
echo
echo "### AutoPkg Repos Configured"

# make recipe overrides for some packages
while read -r line; do
    if [[ -z $(echo $line | grep "#") ]]; then
        ${AUTOPKG} make-override "$line"
    fi
done < "${AUTOPKG_RECIPE_LIST}"
echo
echo "### AutoPkg Overrides updated"

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
/usr/local/munki/iconimporter

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
