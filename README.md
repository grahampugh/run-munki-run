# run-munki-run

This is a one command Munki + MunkiWebAdmin2 + Munki-Do + Sal installation using [Docker].
(You can choose whether you want MWA2 and/or Munki-Do in the settings).
It also installs MunkiTools and AutoPkg on your machine
and populates your repo with a few packages from AutoPkg.
Finally, it creates a preconfigured Client Installer you can distribute to clients.

# Prerequisites
1. [Docker for Mac][Docker] should be installed. *
2. Mac must be a 2010 or newer model, with Intel’s hardware support for memory
   management unit (MMU) virtualization; i.e., Extended Page Tables (EPT) *
3. OS X 10.10.3 Yosemite or newer
4. At least 4GB of RAM

**Note:** Run-Munki-Run also works experimentally on older Macs. On these Macs you
should install [Docker Toolbox] and run
`/Applications/Docker/QuickStart Terminal.app` to set up the `default` Docker Container.

# Operation:

1. Edit the settings in `settings.sh`. This includes the path to the Munki repo and Sal/MWA2/Munki-Do
   database locations, and the list of default applications to add to AutoPkg.
   There are many other settings you can alter, such as
   host ports in case you are already running Docker sites.
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

# Acknowledgements

   * The RUN-ME-FIRST script borrows heavily from
     [Tom Bridge's excellent Munki-In-A-Box](https://github.com/tbridge/munki-in-a-box).

[Docker]: https://github.com/tbridge/munki-in-a-box
[Docker Toolbox]: https://www.docker.com/products/docker-toolbox
