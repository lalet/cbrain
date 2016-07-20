#!/bin/bash -e

source /home/cbrain/.bashrc

source /home/cbrain/cbrain/Docker/entry_points/functions.sh

#####################
# Utility functions #
#####################

# Installs the plugins in the portal. Plugins may be dropped in a
# persistent volume outside of the container at any time. We should
# make sure they are properly installed before we boot the portal.
function install_plugins_portal {
    cd ${HOME}/cbrain/BrainPortal/cbrain_plugins             || die "Cannot cd to \
                                                                ${HOME}/cbrain/BrainPortal/cbrain_plugins"
    for plugin_dir in `ls -d /home/cbrain/plugins/* 2>/dev/null`
    do
        echo "Found plugin ${plugin_dir}"
        test -d `basename ${plugin_dir}` || ln -s ${plugin_dir}                                  || die "Cannot ln -s ${plugin_dir}"
    done
    cd ${HOME}/cbrain/BrainPortal                            || die "Cannot cd to \
                                                                     BrainPortal directory"
    bundle install                                           || die "Cannot bundle install"
    rake cbrain:plugins:install:all                          || die "Cannot install plugins"
}

function update_dp_cache_dir {
    mysql ${MYSQL_DATABASE} ${MYSQL_OPTIONS} -e "update remote_resources set dp_cache_dir='/home/cbrain/cbrain_data_cache'"
}

# Runs all the scripts in Docker/init_portal in the rails console of the portal
function configure_portal {
    update_dp_cache_dir
    cd ${HOME}/cbrain/BrainPortal
    for script in `ls ${HOME}/cbrain/Docker/init_portal/*.rb`
    do
        echo "Running ${script}"
        rails r ${script} || die "${script} failed."
    done
}

# Runs a simple query to make sure we can access the DB.
function check_connection {
    mysql ${MYSQL_OPTIONS} -e "show databases;" &>/dev/null
}

# Checks if the DB has been initialized. A more robust check might exist.
function check_initialized {
    mysql ${MYSQL_OPTIONS} -e "show databases;" | grep ${MYSQL_DATABASE} &>/dev/null || die "CBrain database $MYSQL_DATABASE does not exist"
    mysql ${MYSQL_DATABASE} ${MYSQL_OPTIONS} -e "select 1 from active_record_logs limit 1;" &>/dev/null
}

# Initializes the CBRAIN application (DB and DP cache dir)
function initialize {
    echo "Initializing DB"

    # DB initialization, seeding, and sanity check
    cd $HOME/cbrain/BrainPortal             || die "Cannot cd to BrainPortal directory"
    bundle                                  || die "Cannot bundle Rails application"
    rake db:schema:load RAILS_ENV=${MODE}   || die "Cannot load DB schema"
    rake db:seed RAILS_ENV=${MODE}          || die "Cannot seed DB"
    rake db:sanity:check RAILS_ENV=${MODE}  || die "Cannot sanity check DB"

    # Some configuration scripts may need plugins to be installed
    install_plugins_portal

    configure_portal
}

###############
# Main script #
###############

if [ -z "$MODE" ]
then
    echo "usage: portal.sh with the following environment variables:"
    echo
    echo "MODE:"
    echo "     development: starts the application in Rails development mode."
    echo "     test:        starts the application in Rails test mode."
    echo "     production:  starts the application in Rails production mode."
    echo "MYSQL_HOST: host for MySQL database"
    echo "MYSQL_PORT: port for MySQL database"
    echo "MYSQL_USER: user to connect to MySQL database"
    echo "MYSQL_PASSWORD: password to connect to MySQL database"
    echo "MYSQL_DATABASE: name of the MySQL database to use for CBrain"
    exit 1
fi

# Sets mysql HOST and PORT
MYSQL_HOST=${MYSQL_HOST:-mysql}
MYSQL_PORT=${MYSQL_PORT:-3306}
MYSQL_DATABASE=${MYSQL_DATABASE:-cbrain}
[[ "x${MYSQL_USER}" != "x" ]]     || die "MYSQL_USER is not defined."
[[ "x${MYSQL_PASSWORD}" != "x" ]] || die "MYSQL_PASSWORD is not defined."
export MYSQL_OPTIONS="-h ${MYSQL_HOST} -P ${MYSQL_PORT} -u ${MYSQL_USER} --password=${MYSQL_PASSWORD}"

# Edits DB configuration file from template
dockerize -template $HOME/cbrain/Docker/templates/database.yml.TEMPLATE:$HOME/cbrain/BrainPortal/config/database.yml || die "Cannot edit DB configuration file"

# Edits portal name from template
dockerize -template $HOME/cbrain/Docker/templates/config_portal.rb.TEMPLATE:$HOME/cbrain/BrainPortal/config/initializers/config_portal.rb || die "Cannot edit CBRAIN configuration file"

# Edits data provider configuration from template
dockerize -template $HOME/cbrain/Docker/templates/create_dp.rb.TEMPLATE:$HOME/cbrain/Docker/init_portal/create_dp.rb || die "Cannot edit Create DP configuration file"

# Edits bourreau configuration from template
dockerize -template $HOME/cbrain/Docker/templates/create_bourreau.rb.TEMPLATE:$HOME/cbrain/Docker/init_portal/create_bourreau.rb || die "Cannot edit Create Bourreau configuration file"

# Waits for DB to be available
dockerize -wait tcp://${MYSQL_HOST}:${MYSQL_PORT} -timeout 90s || die "Cannot wait for ${MYSQL_HOST}:${MYSQL_PORT} to be up or timeout was reached"
while ! check_connection
do
  echo "$(date) - still trying to connect to the database"
  sleep 1
done

# Initializes the DB if it was not done before
check_initialized || initialize

echo "Starting portal"
rm -f /home/cbrain/cbrain/BrainPortal/tmp/pids/*.pid
rm -f ${HOME}/.ssh/known_hosts
install_plugins_portal
cd $HOME/cbrain/BrainPortal                  || die "Cannot cd to BrainPortal directory"
exec rails server thin -e ${MODE} -p 3000    || die "Cannot start BrainPortal"
