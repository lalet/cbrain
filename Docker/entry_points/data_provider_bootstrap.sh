#!/bin/bash -e

source /home/cbrain/entry_points/functions.sh

###############
# Main script #
###############

if [ -z "$USERID" ] || [ -z "$GROUPID" ] || [ -z "${PORTAL_PORT}" ] || [ -z "${PORTAL_HOST}" ]
then
    echo "usage: bourreau_bootstrap.sh with the following environment variables"
    echo
    echo "USERID: ID of the user that will run the CBRAIN bourreau."
    echo
    echo "GROUPID: group ID of the user that will run the CBRAIN bourreau."
    echo
    echo "PORTAL_PORT: the port where the CBRAIN portal is started."
    echo
    echo "PORTAL_HOST: the host where the CBRAIN portal is started."
    exit 1
fi

groupmod -g ${GROUPID} cbrain || die "groupmod -g ${GROUPID} cbrain failed"
usermod -u ${USERID} cbrain  || die "usermod -u ${USERID} cbrain" # the files in /home/cbrain are updated automatically
for volume in /home/cbrain/data \
         /home/cbrain/.ssh
do
    echo "chowning ${volume}"
    chown cbrain:cbrain ${volume}
done
generate_ssh_host_keys

# Initialize Bourreau configuration and plugins
su cbrain "/home/cbrain/entry_points/data_provider.sh"

echo "Starting data provider"
exec /usr/sbin/sshd -D 
