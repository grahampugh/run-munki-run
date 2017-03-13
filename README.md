# run-munki-run

This set of scripts is intended to make setting up a Munki service easy.
It is similar to Tom Bridge's [Munki-In-A-Box], and uses parts of that script,
but does not rely on an existing web service such as the Mac Server.app.

## What does it do?

   * Downloads and installs the Munki tools on your Mac
   * Downloads and installs AutoPkg on your Mac
   * Creates a Munki repository in a location of your choice
   * Builds a preconfigured Munki Client Installer that you can distribute to clients
   * Adds AutoPkg repositories, makes Recipe Overrides and runs the recipes to
     populate your Munki repository
   * Creates a Docker container that serves the Munki repository
   * Creates a Docker container that serves the Sal reporting service
   * Creates a Docker container that serves MunkiWebAdmin2
   * Creates a Docker container that serves Munki-Do
   * Contains a script to generate a Sal client setup package

Many of these features can be disabled, for instance if you don't want to build Munki-Do and MunkiWebAdmin2,
just disable one of them in the settings.

## Anything else?

Yes! You can now (experimentally) run this script on Ubuntu. See Linux Support below for details.

---

# Prerequisites for Mac installation
1. [Docker for Mac][Docker] should be installed. *
2. Mac must be a 2010 or newer model, with Intel’s hardware support for memory
   management unit (MMU) virtualization; i.e., Extended Page Tables (EPT) *
3. OS X 10.10.3 Yosemite or newer
4. At least 4GB of RAM

**Note:**
Run-Munki-Run also works experimentally on older Macs. On these Macs you
should install [Docker Toolbox] and run
`/Applications/Docker/QuickStart Terminal.app` to set up the `default` Docker machine.

---

# Operation:

1. `git clone` this repo.
1. Edit the settings in `settings.sh`. This includes the path to the Munki repo and Sal/MWA2/Munki-Do
   database locations, and the list of default applications to add to AutoPkg.
   There are many other settings you can alter.
2. Run `./RUN-ME-FIRST.sh`
3. Install Munkitools on some clients.
4. If you have access to DNS, create an alias to the Docker host named
   `munki.yourname.com` and add an alias (CNAME) of `munki`. You need to
   reverse proxy from my-docker-host:port to munki:80 (by default). You will then not need to
   configure Munki on the client. If you cannot create an alias, then set the ServerURL
   on the client with the following command:  

   `sudo defaults write /Library/Preferences/ManagedInstalls.plist ServerURL http://my-docker-host:port/repo`

5. To enable reporting, configure Sal, and push out the Sal preferences to the
   clients (e.g. in a package). Instructions for setting up Sal are given below.

You should only need to run `./RUN-ME-FIRST.sh` once, but it won't break things if you
run it again.

To restart the Docker containers, run `./run-munki-run.sh`.

To stop the containers, run `./clean-up.sh`

---

# Configuring Sal

1. Open Sal at http://my-docker-host:sal-port (the output from `run-munki-run.sh` will show the correct URL to use)
2. Create a business unit named 'default' and a machine group named 'site_default'.
3. Choose the 'person' menu at the top right and then choose Settings.
4. From the sidebar, choose API keys and then choose to make a new one.
5. Give it a name so you can recognise it - e.g. 'PKG Generator'.
6. You will then be shown a public key and a private key.
7. Enter the following command in terminal to generate the enroll package (substituting `sal_url` appropriately):

```
python sal_package_generator.py --sal_url=http://my-docker-host:sal-port --public_key=<PUBLIC_KEY> --private_key=<PRIVATE_KEY> --pkg_id=com.salopensource.sal_enroll
```

8. Enter the following commands to import the package to Munki:

```
munkiimport sal-enroll-site_default.pkg --subdirectory config/sal --unattended-install --displayname=\"Sal Enrollment for site_default\" --developer=\"Graham Gilbert\" -n
manifestutil add-pkg sal-enroll-site_default --manifest $MUNKI_DEFAULT_SOFTWARE_MANIFEST
makecatalogs
```

---

# Linux support

Experimental support for Run-Munki-Run on Linux is now in place. So far, this is tested on an Ubuntu 14.04 LTS Virtual Machine running on a Mac.

This uses Docker Community Edition for Ubuntu, set up as per the instructions [here](https://docs.docker.com/engine/installation/linux/ubuntu/). The Docker setup is not as yet included in the run-munki-run scripts, but could easily be added.

To get going on your Linux host:

1. Setup Docker as above.
1. `git clone` this repo.
1. Edit the settings in `settings-linux.sh`. This includes the path to the Munki repo and Sal/MWA2/Munki-Do
   database locations.
2. Run `./RUN-ME-FIRST-linux.sh`

**Notes:**
   * AutoPkg can only run on Mac, so is not included here.
   * Currently, the script can set up the repo folders but not populate them, as this requires the Mac-only munkitools. See **No-Server Setup** below.
   * If your Virtual Machine is running on a Mac, you can choose a shared folder on the host Mac, so that you can populate the repo locally on the Mac.
     Follow the **No-Server Setup** instructions below on your Mac to install just the Mac-specific tools.
   * If you are running this script on a physical Linux host or remote VM, you should set up SMB sharing on the VM,
     and share the directory so that you can mount the folder from a Mac.

---

# No-Server Setup

If you just want to install the Munki tools and Autopkg on your Mac, and create a Munki repo and populate it:

   * Set `NOSERVERSETUP=True` in `settings.sh` and run the `RUN-ME-FIRST.sh` script to setup the Munki repo at `/Users/Shared`.

Possible scenarios for this include:

   * You are using the Mac Server.app to serve the Munki repo.
   * You are setting the Munki repo up on a shared folder that is hosted on another computer, such as a Linux VM (see Linux Support above).

---

# Acknowledgements

   * The RUN-ME-FIRST script borrows heavily from
     [Tom Bridge's excellent Munki-In-A-Box][Munki-In-A-Box]. Thanks Tom!


[Munki-In-A-Box]: https://github.com/tbridge/munki-in-a-box
[Docker]: https://github.com/tbridge/munki-in-a-box
[Docker Toolbox]: https://www.docker.com/products/docker-toolbox
