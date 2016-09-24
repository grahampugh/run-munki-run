#!/bin/bash

# This checks whether munki munki-do etc are running and stops them
# if so (thanks to Pepijn Bruienne):
echo "### Stopping and removing old Docker instances..."
docker ps -a | sed "s/\ \{2,\}/$(printf '\t')/g" | \
	awk -F"\t" '/apache|munki|munki-do|mwa2|sal|postgres-sal|gitlab|gitlab-postgresql|gitlab-redis/{print $1}' | \
	xargs docker rm -f
echo "### ...done"
echo
