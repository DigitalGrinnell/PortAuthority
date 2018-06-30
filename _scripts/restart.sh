#!/bin/bash

echo
echo "${0} called with parameters: ${@}"
echo "--------------------------------------------------------------------"

# Help menu
print_help() {
cat <<-HELP
This script can be used to RESTART one or more site stacks.

  One or more parameters is required to specify the site(s) you wish to restart.

       --ohscribe : The 'OHScribe!' Python3/Flask app site
            --all : All of the above
      --portainer : The Portainer Docker management site

HELP
exit 0
}

# Each site 'stack' generally consists of the following containers...
dir="${HOME}/Projects/Docker/PortAuthority/_sites"
# declare -a containers=( "nginx" "php" "mariadb" )  # "adminer" )

# Add in our .master.env environment variables
source ${HOME}/Projects/Docker/PortAuthority/.master.env

# Attempt to detect which host OS we are building on here.  This generally determines our target base domain.
echo "OSTYPE is... '$OSTYPE'"
if [[ $OSTYPE == darwin* ]]; then
  echo "On OSX";
  domain="docker.localhost"
elif [[ $OSTYPE == Linux* ]]; then
  echo "On CentOS";
  domain="grinnell.edu"
elif [[ $OSTYPE == linux* ]]; then
  echo "On CentOS";
  domain="grinnell.edu"
else
  echo "OS type was not detected.  Assuming domain is docker.localhost"
  domain="docker.localhost"
fi

# Parse Command Line Arguments
case "$1" in
  --portainer)
    declare -a sites=( "portainer" )
    declare -a containers=( "portainer" )   # Portainer has only one container
    ;;
  --ohscribe)
    declare -a sites=( "admin" )
    ;;
  --all)
    declare -a sites=( "ohscribe" )
    ;;
  --help)
    print_help
    ;;
  *)
    printf ""
    printf "************************************************************\n"
    printf "* Error: Invalid argument, run --help for valid arguments. *\n"
    printf "************************************************************\n"
    exit 1
esac

# Make sure the 'proxy' network is up!
if [ ! "$(docker network ls | grep proxy)" ]; then
  cmd="docker network create proxy"
  echo "Creating 'proxy' network with '${cmd}'."
  ${cmd}
else
  echo "The 'proxy' network already exists.  Moving on."
fi


# Make sure Traefik is running!
RUNNING=$(docker inspect --format="{{.State.Running}}" traefik 2> /dev/null)
if [[ ${RUNNING} != "true" ]]; then
  cmd="docker run -d \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v ${HOME}/Projects/Docker/PortAuthority/traefik/traefik.toml:/traefik.toml \
    -v ${HOME}/Projects/Docker/PortAuthority/traefik/acme.json:/acme.json \
    -p 80:80 \
    -p 443:443 \
    -l traefik.frontend.rule=Host:traefik.${domain} \
    -l traefik.port=8080 \
    --network proxy \
    --name traefik \
    traefik:1.5.2-alpine --docker"
  echo "Starting Traefik per ${cmd}"
  ${cmd}
else
  echo "Traefik is already up. Moving on."
fi


# Process each requested site(s)...

for site in "${sites[@]}"
do

  # Stop all pertinent containers
  for container in "${containers[@]}"
  do
    stamp=`date +%Y%m%d-%H%M`
    cmd="docker stop ${site}_${container}"
    echo "${stamp}: ${cmd}"
    ${cmd}
  done

  # Now remove the stopped containers and any unused, not-persistent, associated volumes
  for container in "${containers[@]}"
  do
    stamp=`date +%Y%m%d-%H%M`
    cmd="docker rm -v ${site}_${container}"
    echo "${stamp}: ${cmd}"
    ${cmd}
  done

  # Bring 'em back up using the site's docker-compose.yml
  stamp=`date +%Y%m%d-%H%M`
  cd ${dir}/${site}
  cmd="docker-compose up -d"
  echo "${stamp}: ${cmd}"
  ${cmd}
  cd -

done

echo "Done."
echo ""
