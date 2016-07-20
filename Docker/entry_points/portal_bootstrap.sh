#!/bin/bash -e

source /home/cbrain/cbrain/Docker/entry_points/functions.sh

###############
# Main script #
###############

if [ -z "$MODE" ] || [ -z "$USERID" ] || [ -z "$GROUPID" ]
then
    echo "usage: portal_bootstrap.sh with the following environment variables"
    echo
    echo "MODE:"
    echo "     development: starts the application in Rails development mode."
    echo "     test:        starts the application in Rails test mode."
    echo "     production:  starts the application in Rails production mode."
    echo
    echo "USERID: ID of the user that will run the CBRAIN portal."
    echo
    echo "GROUPID: group ID of the user that will run the CBRAIN portal."
    exit 1
fi

groupmod -g ${GROUPID} cbrain || die "groupmod -g ${GROUPID} cbrain failed"
usermod -u ${USERID} cbrain  || die "usermod -u ${USERID} cbrain" # the files in /home/cbrain are updated automatically
for volume in /home/cbrain/cbrain_data_cache \
         /home/cbrain/.ssh \
         /home/cbrain/plugins \
         /home/cbrain/data_provider
do
    echo "chowning ${volume}"
    chown cbrain:cbrain ${volume}
done
for volume in /home/cbrain/cbrain_data_cache \
         /home/cbrain/.ssh
do
    echo "changing permissions for ${volume}"
    chmod 700 ${volume}
done

exec su cbrain "/home/cbrain/cbrain/Docker/entry_points/portal.sh"
