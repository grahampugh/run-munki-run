#!/bin/bash

# On older Macs Docker cannot run natively and the Docker Toolbox is required, which
# uses VirtualBox and boot2docker

# import the settings
. settings.sh

# Check if the Munki server  website is up - if so, no need to restart it
curl -s -o "/dev/null" "http://${IP}/${REPONAME}/catalogs/all"
if [ $? -ne 0 ] ; then
    echo
    echo "### We need to configure Virtual Box"
    echo
    # Check that Docker Machine exists
    if [[ "$(docker-machine ls | grep default)" ]]; then
    	echo
    	echo "### Note that Docker-Machine is a development environment."
    	echo "### Think carefully before using this in Production."
    	echo

    	# Check that Docker Machine is running, or that this is the first run so we need to
    	# set up the port forwarding in VirutalBox
    	if [[ "$(docker-machine status default)" == "Running" ]]; then
    		docker-machine stop default
        fi

        # (Re)assign port-forwarding in the VM
    	VBoxManage modifyvm "default" --natpf1 delete "munki-do"
    	VBoxManage modifyvm "default" --natpf1 delete "munki"
    	VBoxManage modifyvm "default" --natpf1 delete "mwa2"
    	VBoxManage modifyvm "default" --natpf1 delete "sal"
    	# setup the required port forwarding on the VM
    	VBoxManage modifyvm "default" --natpf1 "munki-do,tcp,,$MUNKI_DO_PORT,,$MUNKI_DO_PORT"
    	VBoxManage modifyvm "default" --natpf1 "munki,tcp,,$MUNKI_PORT,,$MUNKI_PORT"
    	VBoxManage modifyvm "default" --natpf1 "mwa2,tcp,,$MWA2_PORT,,$MWA2_PORT"
    	VBoxManage modifyvm "default" --natpf1 "sal,tcp,,$SAL_PORT,,$SAL_PORT"

    	# start the machine
    	docker-machine restart default

        # Get the IP address of the machine
        VM_IP=$(docker-machine ip default)
        echo "Your Docker-Machine IP address is: $VM_IP"
        echo
    else
        echo
        echo "--- ACTION REQUIRED ---"
        echo "The 'default' docker-machine does not exist. You should run the Quickstart Terminal app to set it up."
        echo "---"
        echo
        exit 0
    fi
else
    echo "Website is up, so nothing required here."
fi
