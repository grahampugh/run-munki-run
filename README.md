# run-munki-run

This is a one command Munki + MunkiWebAdmin2 + Munki-Do + Sal installation 
(You can choose whether you want MWA2 and/or Munki-Do in the settings).
It also installs MunkiTools, AutoPkg, AutoPkgr and MunkiAdmin on your machine
and populates your repo with a few packages from AutoPkg.

# Prerequisites
1. [Docker for Mac](https://download.docker.com/mac/stable/Docker.dmg) should be installed.
2. Mac must be a 2010 or newer model, with Intel’s hardware support for memory 
   management unit (MMU) virtualization; i.e., Extended Page Tables (EPT)
3. OS X 10.10.3 Yosemite or newer
4. At least 4GB of RAM 

# Operation:

1. Edit the settings in `settings.sh`. This includes the Munki repo and Sal/MWA2 
   database locations, the list of default applications to add to AutoPkg, and 
   (optionally, if you have access to DNS) some real hostnames for Munki, 
   MunkiWebAdmin2 and Sal. There are many other settings you can alter, such as 
   host ports in case you are already running Docker sites.
2. Run `./RUN-ME-FIRST.sh`
3. Install Munkitools on some clients. 
4. If you have access to DNS, create an alias to the Docker host named 
   `munki.yourname.com` and add an alias (CNAME) of `munki`. You need to 
   reverse proxy from my-docker-host:port to munki:80. You will then not need to 
   configure Munki on the client. If you cannot create an alias, then set the ServerURL 
   on the client with the following command:  
   
   `sudo defaults write /Library/Preferences/ManagedInstalls.plist ServerURL http://my-docker-host:port/repo`
   
5. To enable reporting, configure Sal, and push out the Sal preferences to the 
   clients (e.g. in a package).

You should only need to run `./RUN-ME-FIRST.sh` once, but it won't break things if you
run it again. 

To restart the Docker containers, run `./run-munki-run.sh`.

To stop the containers, run `./clean-up.sh`

# Acknowledgements

   * The RUN-ME-FIRST script borrows heavily from 
     [Tom Bridge's excellent Munki-In-A-Box](https://github.com/tbridge/munki-in-a-box).


