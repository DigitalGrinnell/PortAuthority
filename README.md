# PortAuthority

This project is a copy of my earlier SummittServices.com (SS) project work.  It's essentiall a stripped-down version of _SS_ with only _Traefik_ and _Portainer_ left in the original.  

## Project Goal

The goal of this project is to document and build, in Docker, a pair of stack "management" tools, namely _Traefik_ and _Portainer_, along with a place to add new stacks, namely the *_sites* folder.  The project should support easy local development (DEV) and deployed production (PROD) environments.  The local/development environment should be easily engaged with XDebug and IDEs like PyCharm and PHPStorm.  The deployed production services should be easy to encrypt for secure SSL/TLS access and suitable for occupying a single Docker-ready VPS of reasonable scale.

## Current Project Structure

```
PortAuthority  
|--_scripts  
   |--restart.sh
|--_sites
   |--portainer
      |--docker-compose.yml  
|--traefik  
   |--acme.json
   |--traefik.toml
|--.master.env
|--.remote-sync.json
|--README.md
```

## Basics
Some "as-built" resources and documents...

- The project environments are:

    - DEV = OSX host, my MacBook Air
    - STAGE = CentOS 7 host, my home Docker server
    - PROD = Grinnell College's DGDockerX CentOS 7 host

- Development and deployment are designed around the practice of "Code Up, Data Down".  Essentially, code is pushed up from DEV to PROD only, while data (databases and data files) are pulled only from PROD down to DEV.

- Network management leverages Traefik (https://docs.traefik.io/).  It makes obtaining and maintaining SSL/TLS certs a breeze.  

- Portainer (https://portainer.io/) is used to assist with management of the entire environment.  

- Lumogon (https://lumogon.com/) is used to inventory the environment as needed.  

- Atom is used for much of the editing and its _remote-sync_ package (defined in _.remote-sync.json_) is employed to sync modifications between my MacBook Air (DEV) and PROD.


## Portainer

I have really become dependent on _Portainer_ to assist with all my Docker management activities, so much so that I decided to make it a 'site' of its own running in parallel to my other sites.  Note that _Portainer_ is launched with a `docker-compose.yml` file which includes _command_ and _volumes_ specs like this:

```
command: ${PORTAINER_AUTH} -H unix:///var/run/docker.sock
volumes:
  - /var/run/docker.sock:/var/run/docker.sock
```

This means that a single instance of it running on your Docker host can detect EVERY container on the host.  So you only need ONE _Portainer_ per host, not one for every container as some bloggers apparently believe.

My PROD instance of _Portainer_ can be found at https://portainer.grinnell.edu, but it's password protected (as is https://traefik.grinnell.edu) so you can't necessarily see it.


## Scripts and Environment - Tieing It All Together

Very early on I created the *_scripts* directory to hold some of the _bash_ that I'd use to keep things tidy.  I also started with the notion of keeping all my secrets (passwords mostly) in _.env_ files, but this became cumbersome so I have consolidated all secrets here into a single _.master.env_ file.

### .env File

Clauses like `${PORTAINER_AUTH}` that you see in the code snippet above are references to these environment variables.  The `docker-compose` command automatically reads any `.env` file it finds in the same directory as the `docker-compose.yml` it is reading, so I followed suit by putting a `.env` file in every such directory.

`.env` files are also environment-specific.  There's a set of them for DEV and a **different** set for PROD, with some different values in each environment.  For example, in DEV `${PORTAINER_AUTH}` has a value of '--no-auth' specifying that no login/authorization is required; but in PROD that variable is set to '--admin-password $2y$05$Fh2wW6kMJVo8tkirrRYYYOkwvPKMVdkRqmZOUi7bHerJTNVoQfyWC' which specifies that the _admin_ username requires a password for authentication.

A technique documented in https://docs.docker.com/compose/environment-variables/ is employed here to manage environment variables.

### restart.sh

I created the _restart.sh_ script in the *_scripts/* folder to assist with starting, or re-starting, a single site and it's containers. Specifically it...

  - Ensures that the external _proxy_ network is up and running.

  - Is home to the `docker run -d...` command from Step 2 above, and it ensures that Traefik is up and running.

  - Stops, then removes, all containers and unused not-persistent volumes associated with the site(s) which are to be started or re-started.

  - Invokes a `docker-compose up -d` command for each targeted site to bring them back up one-at-a-time.

See *_scripts/restart.sh* for complete details.
