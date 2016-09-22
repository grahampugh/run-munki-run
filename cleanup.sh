#!/bin/bash

# This checks whether munki munki-do etc are running and stops them
# if so (thanks to Pepijn Bruienne):
echo "### Stopping and removing old Docker instances..."
docker ps -a | sed "s/\ \{2,\}/$(printf '\t')/g" | \
	awk -F"\t" '/apache|munki|sal|postgres-sal|mwa2/{print $1}' | \
	xargs docker rm -f
echo "### ...done"
echo