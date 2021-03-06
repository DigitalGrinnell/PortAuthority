#!/bin/bash

# Note that portions of this script tagged with '# change me!' may be specific to 
# Digital Grinnell and should be changed if used elsewhere!

echo
echo "${0} called with parameters: ${@}"
echo "--------------------------------------------------------------------"

# Help menu
print_help() {
cat <<-HELP
This script can be used to RESTART one or more site stacks.  

  One or more parameters is required to specify the site(s) you wish to restart.

       --ohscribe : The 'OHScribe!' Python3/Flask app site        # change me!
            --all : All of the above
      --portainer : The Portainer Docker management site

HELP
exit 0
}

# Each site 'stack' generally consists of the following containers...
proj="${HOME}/Projects/Docker/PortAuthority"
dir="${proj}/_sites"
# declare -a containers=( "nginx" "php" "mariadb" )  # "adminer" )

# Export our .master.env environment variables
set -a
source ${HOME}/Projects/Docker/PortAuthority/.master.env
set +a

# Attempt to detect which host OS we are building on here.  This generally determines our target base domain.
echo "OSTYPE is... '${OSTYPE}'"
if [[ ${OSTYPE} == darwin* ]]; then
  type="OSX"
  domain="docker.localhost"
elif [[ ${OSTYPE} == Linux* ]]; then
  type="CentOS"
  domain="grinnell.edu"                     # change me!
elif [[ ${OSTYPE} == linux* ]]; then
  type="CentOS"
  domain="grinnell.edu"			    # change me!
else
  type="NOT detected"
  domain="docker.localhost"
fi

host=`hostname`
echo "${host}: OS type is '${type}' and domain is '${domain}'"
if [[ ${host} == dgdockerx ]]; then                               # change me!
  sub="traefikX"                                                  # change me!
else
  sub="traefik"
fi

# Parse Command Line Arguments
case "$1" in
  --portainer)
    declare -a sites=( "portainer" )
    declare -a containers=( "portainer" )   # Portainer has only one container
    ;;
  --ohscribe)                                                                    # change me!
    declare -a sites=( "OHScribe" )                                              # change me!
    declare -a containers=( "ohscribe" )   # OHScribe has only one container     # change me!
    ;;
  --all)
    declare -a sites=( "OHScribe" )                                              # change me!
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
    -l traefik.frontend.rule=Host:${sub}.${domain} \
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

  # Bring 'em back up using the site's docker-compose.yml and a copy of .master.env
  stamp=`date +%Y%m%d-%H%M`
  cd ${dir}/${site}
  cp -f ${proj}/.master.env .env
  cmd="docker-compose up -d"
  echo "${stamp}: ${cmd}"
  ${cmd}
#  rm -f .env
  cd -

done

echo "Done."
echo ""
