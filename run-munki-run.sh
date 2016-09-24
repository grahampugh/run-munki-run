#!/bin/bash

# import the settings
. settings.sh

if [[ ! -d "$MUNKI_REPO" ]]; then
	echo
	echo "### Munki Repo not set up. Please run RUN-ME-FIRST.sh instead of this script."
	echo "### Exiting..."
	echo
	exit 0
fi

if [[ $DOCKERTYPE = "none" ]]; then
	echo
	echo "### There's no Docker installed on this Mac."
	echo "### If you have Macs from 2010 and newer can use the native Docker for Mac app."
	echo "### On older Macs, use the Docker Toolbox."
	echo
	exit 0
fi

# On older Macs Docker cannot run natively and the Docker Toolbox is required, which
# uses VirtualBox and boot2docker
if [[ $DOCKERTYPE = "docker-machine"; then
	echo
	echo "### We need to configure Virtual Box"
	echo
	# Check that Docker Machine exists
	if [ -z "$(docker-machine ls | grep run_munki_run)" ]; then
		echo
		echo "### Note that Docker-Machine is a development environment."
		echo "### Think carefully before using this in Production."
		echo
		echo "Creating the run_munki_run docker-machine..."
		echo

		docker-machine create -d virtualbox --virtualbox-disk-size=10000 run_munki_run
		docker-machine env run_munki_run
		eval $(docker-machine env run_munki_run)  # this doesn't seem to work from a script.
	
		echo
		echo "### You need to now run the following command in your terminal "
		echo "### and then re-run this script, sit back and wait for the magic."
		echo "### (try as I might, I cannot get it to work from within the script!)"
		echo "eval \$(docker-machine env run_munki_run)"
		echo 
		touch "$HOME/.munki-is-new"
		exit 0
	fi

	# Ensure that the machine will restart after a reboot
	if [ -f "$HOME/Library/LaunchAgents/com.docker.machine.munkido.plist" ]; then
		cp "com.docker.machine.munkido.plist" "$HOME/Library/LaunchAgents/"
		launchctl load ~/Library/LaunchAgents/com.docker.machine.default.plist
	fi

	# Check that Docker Machine is running, or that this is the first run so we need to 
	# set up the port forwarding in VirutalBox
	if [[ "$(docker-machine status munkido)" != "Running" || -f "$HOME/.munki-do-is-new" ]]; then
		# delete port forwarding assignments, in case we've changed them
		docker-machine stop run_munki_run
		VBoxManage modifyvm "run_munki_run" --natpf1 delete munki-do
		VBoxManage modifyvm "run_munki_run" --natpf1 delete munki
		VBoxManage modifyvm "run_munki_run" --natpf1 delete mwa2
		VBoxManage modifyvm "run_munki_run" --natpf1 delete sal
		# setup the required port forwarding on the VM
		VBoxManage modifyvm "run_munki_run" --natpf1 "munki-do,tcp,,$MUNKI_DO_PORT,,$MUNKI_DO_PORT"
		VBoxManage modifyvm "run_munki_run" --natpf1 "munki,tcp,,$MUNKI_PORT,,$MUNKI_PORT"
		VBoxManage modifyvm "run_munki_run" --natpf1 "mwa2,tcp,,$MWA2_PORT,,$MWA2_PORT"
		VBoxManage modifyvm "run_munki_run" --natpf1 "sal,tcp,,$SAL_PORT,,$SAL_PORT"
		# start the machine
		docker-machine restart run_munki_run
		rm "$HOME/.munki-is-new"
	fi

	# Get the IP address of the machine
	IP=`docker-machine ip run_munki_run`
fi


# if we got this far then we can install munki


# Clean up
. cleanup.sh

echo "### Creating virtual hosts files"
echo
# ensure there's a folder for the virtual hosts files
if [[ ! -d "$VIRTUALHOSTSLOC" ]]; then
    mkdir -p $VIRTUALHOSTSLOC
    # chmod and chown if you need to!
	# create the virtual hosts files:
	## Munki:
	cat > "$VIRTUALHOSTSLOC/$MUNKI_HOSTNAME.conf" <<'ENDMSG'
<VirtualHost *:80>
	ServerName $MUNKI_HOSTNAME
	<Proxy *>
	Allow from localhost
	</Proxy>
	ProxyPass / http://$IP:$MUNKI_PORT/
	</VirtualHost>
ENDMSG
	## Sal:
	cat > "$VIRTUALHOSTSLOC/$SAL_HOSTNAME.conf" <<'ENDMSG'
<VirtualHost *:80>
	ServerName $SAL_HOSTNAME
	<Proxy *>
	Allow from localhost
	</Proxy>
	ProxyPass / http://$IP:$SAL_PORT/
	</VirtualHost>
ENDMSG
	## MWA2
	cat > "$VIRTUALHOSTSLOC/$SAL_HOSTNAME.conf" <<'ENDMSG'
<VirtualHost *:80>
	ServerName $MWA2_HOSTNAME
	<Proxy *>
	Allow from localhost
	</Proxy>
	ProxyPass / http://$IP:$MWA2_PORT/
	</VirtualHost>
ENDMSG
	## MWA2
	if [[ $MUNKI_DO_ENABLED = true ]]; then
		cat > "$VIRTUALHOSTSLOC/$MUNKI_DO_HOSTNAME.conf" <<'ENDMSG'
<VirtualHost *:80>
	ServerName $MUNKI_DO_HOSTNAME
	<Proxy *>
	Allow from localhost
	</Proxy>
	ProxyPass / http://$IP:$MUNKI_DO_PORT/
	</VirtualHost>
ENDMSG

echo "### checking for Sal database folder"
echo
# ensure there's a folder ready for the Sal DB:
if [[ ! -d "$SAL_DB" ]]; then
    mkdir -p $SAL_DB
    # chmod and chown if you need to!
fi

# ensuring the Munki-Do DB folder exists with the correct permissions
if [[ $MUNKI_DO_ENABLED = true ]]; then
	if [[ ! -d "$MUNKI_DO_DB" ]]; then
    	mkdir -p "$MUNKI_DO_DB"
    	# chmod and chown if you need to!
	fi
fi

echo "### Apache Docker..."
# Apache container for virtual hosts
docker run -d --name="apache" \
	-v $VIRTUALHOSTSLOC:/bitnami/apache/conf/vhosts \
	-p 80:80 \
	bitnami/apache:latest

echo
echo "### Munki Server Docker..."
# Munki server container
docker run -d --restart=always --name="munki" \
	-v $MUNKI_REPO:/munki_repo \
	-p $MUNKI_PORT:80 -h munki groob/docker-munki

echo
echo "### MunkiWebAdmin2 Server Docker..."
# munkiwebadmin2 container
docker run -d --restart=always --name "mwa2" \
	-p $MWA2_PORT:8000 \
	-v $MUNKI_REPO:/munki_repo \
	-v $MWA2_DB:/mwa2-db \
	grahamrpugh/mwa2

echo
echo "### Sal Server Docker..."
#sal-server container
docker run -d --name="sal" \
  --restart="always" \
  -p $SAL_PORT:8000 \
  -v $SAL_DB:/home/docker/sal/db \
  -e ADMIN_PASS=pass \
  -e DOCKER_SAL_TZ="Europe/Berlin" \
  macadmins/sal

if [[ $MUNKI_DO_ENABLED = true ]]; then
	# munki-do container
	echo
	echo "### Munki-Do Docker..."
	docker run -d --restart=always --name munki-do \
		-p $MUNKI_DO_PORT:8000 \
		-v $MUNKI_REPO:/munki_repo \
		-v $MUNKI_DO_DB:/munki-do-db \
		-e DOCKER_MUNKIDO_TIME_ZONE="$TIME_ZONE" \
		-e DOCKER_MUNKIDO_LOGIN_REDIRECT_URL="$LOGIN_REDIRECT_URL" \
		-e DOCKER_MUNKIDO_ALL_ITEMS="$ALL_ITEMS" \
		-e DOCKER_MUNKIDO_GIT_PATH="$GIT_PATH" \
		-e DOCKER_MUNKIDO_GIT_BRANCHING="$GIT_BRANCHING" \
		-e DOCKER_MUNKIDO_GIT_IGNORE_PKGS="$GIT_IGNORE_PKGS" \
		-e DOCKER_MUNKIDO_MANIFEST_RESTRICTION_KEY="$MANIFEST_RESTRICTION_KEY" \
		grahamrpugh/munki-do

	## GITLAB settings (ignored if $GIT_PATH and $GITLAB_DATA are not set in settings.sh)
	# This part definitely needs more documentation, so consider this "advanced" usage only.

	if [ $GIT_PATH && $GITLAB_DATA ]; then
		echo 
		echo "### You've opted to install Gitlab. Brave choice!"
		# Gitlab-postgres database
		echo
		echo "### Let's start by creating the PostgreSQL database container required by Gitlab..."
		echo "### Note that if you are using Docker-Machine, then due to a permissions issue "
		echo "### this must be installed within the boot2docker VM, so the data would be "
		echo "### lost if you destroy the docker-machine. "
		docker run --name gitlab-postgresql -d \
			--env '$DB_NAME' \
			--env '$DB_USER' --env '$DB_PASS' \
			--volume $GITLAB_DATA/postgresql:/var/lib/postgresql \
			quay.io/sameersbn/postgresql

		# Gitlab Redis instance
		echo
		echo "### The Gitlab Redis instance also links to within the docker-machine"
		docker run --name gitlab-redis -d \
			--volume $GITLAB_DATA/redis:/var/lib/redis \
			quay.io/sameersbn/redis:latest

		# Gitlab container. 
		echo
		echo "### The Gitlab container also links to within the docker-machine"
		docker run --name gitlab -d \
			--link gitlab-postgresql:postgresql --link gitlab-redis:redisio \
			--publish GITLAB_SSH_PORT:22 --publish $GITLAB_PORT:80 \
			--env '$GITLAB_PORT' --env '$GITLAB_SSH_PORT' \
			--env '$GITLAB_SECRETS_DB_KEY_BASE' \
			--volume $GITLAB_DATA/gitlab:/home/git/data \
			quay.io/sameersbn/gitlab:8.1.0-2

		# Docker-gitlab:
		echo
		echo "### Since ssh-keyscan doesn't generate the correct syntax, you need to "
		echo "### copy the line directly from your OS X host's known_hosts file into the "
		echo "### `echo` statement. You must manually make a connection to the git repo in order"
		echo "### to generate the ssh key:"
		cat ~/.ssh/known_hosts | grep $IP > docker/known_hosts

		echo "### Note: after first run, you will need to set up your Gitlab repository. This involves:"
		echo "### Logging in via a browser (http://IP-address:10080). "
		echo "### Default username (root) and password (5iveL!fe)."
		echo "### Changing the password"
		echo "### Logging in again with the new password"
		echo "### Clicking +New Project"
		echo "### Setting the project path to 'munki_repo'"
		echo "### Select Visibility Level as Public"
		echo "### Click Create Project"
		echo "### If you haven't already created an ssh key, do so using the hints at "
		echo "### http://IP-address:10080/help/ssh/README"
		echo "### In Terminal, enter the command 'pbcopy < ~/.ssh/id_rsa.pub'"
		echo "### If recreating a destroyed docker-machine, you need to remove the existing entry from"
		echo "###   ~/.ssh/known_hosts"
		echo "### If you aren't on master branch, `git checkout -b origin master`"
		echo "### Push the branch you are on using `git push --set-upstream origin master`"
	fi
	## END of GITLAB settings
fi

echo
echo "### All done!"
echo "###"
echo "### Your Munki URL is: http://$MUNKI_HOSTNAME or http://$IP:$MUNKI_PORT"
echo "### Test your Munki URL with: http://$IP:$MUNKI_PORT/$REPONAME/catalogs/all"
echo "### Your MWA2 URL is: http://$SAL_HOSTNAME or http://$IP:$SAL_PORT"
echo "### Your Sal URL is: http://$MWA2_HOSTNAME or http://$IP:$MUNKI_DO_PORT"
if [[ $MUNKI_DO_ENABLED = true ]]; then
	echo "### Your Munki-Do URL is: http://$MUNKI_DO_HOSTNAME or http://$IP:$MUNKI_DO_PORT"
fi
echo
echo "Don't forget to set your Sal client preferences. Open Sal at the above address,"
echo "create a business unit and a machine group, and then copy the key into "
echo "sal-client-setup.sh. You then need to run this file on the client, e.g. "
echo "via a Munki package:"
echo 
echo "---"
echo "#!/bin/bash"
echo "sudo defaults write /Library/Preferences/com.github.salopensource.sal.plist ServerURL \"http://$MWA2_HOSTNAME\""
echo "sudo defaults write /Library/Preferences/com.github.salopensource.sal.plist key \"verylongnumberinSalinterface\""
echo "---"
echo



