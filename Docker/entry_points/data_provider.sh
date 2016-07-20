#!/bin/bash -e

source /home/cbrain/.bashrc

source /home/cbrain/entry_points/functions.sh

# Wait for the portal to start so that we are sure that the ssh keys
# are already created
dockerize -wait tcp://${PORTAL_HOST}:${PORTAL_PORT} -timeout 120s || die "Cannot wait for ${PORTAL_HOST}:${PORTAL_PORT} to be up or timeout was reached"

# Automatic exchange of SSH keys
test -f /home/cbrain/.portal_ssh/id_cbrain_portal.pub || die "Cannot find portal public key in /home/cbrain/.portal_ssh/id_cbrain_portal.pub"

cat /home/cbrain/.portal_ssh/id_cbrain_portal.pub >> /home/cbrain/.ssh/authorized_keys
chmod 600 /home/cbrain/.ssh/authorized_keys
