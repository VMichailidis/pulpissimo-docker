<!-- https://github.com/andreamerello/docker-ssh-gui -->
<!-- https://www.xilinx.com/support/download.html -->

# Requirements
- Docker 
- make
- a running x11 server

# Installation

## Download Vivado Installer
Download the Xilinx Unified Installer (89.4 GB) [from https://www.xilinx.com/support/download.html] for Vivado 2022.2 and place it in the install_files directory.

## Build the container from the docker file with
``
make build
``

## Start the container with 
``
bash run
``

## Get local version of pulp platform
In order to make modifications to the pulp source code, it is ideal that you keep a local version that you copied from the container.
To obtain the local copy spin up a container
``
bash run
``
In a different terminal, get the name of the running container instance
``
docker container ls
``
Identify the name of the current container 
``
CONTAINER ID   IMAGE     COMMAND       CREATED       STATUS       PORTS     NAMES
edf925ab3f1b   pulp      "/bin/bash"   6 hours ago   Up 6 hours   22/tcp    focused_golick
``
In the above example the container you just created has the name focused_golick.
And copy the original pulp source code to your local machine.
``
docker container cp focused_golick:/home/pulp/.pulp-platform <path/to/local/copy>
``

Now you can start the container and load your local copy of the pulp source code by running:
``
bash run <path/to/local/copy>
``

# Vivado

If you wish to use another vivado version, you need to change the Dockerfile to point to the correct installer and potentially generate a valid a new configuration file for the unattended installer.
To do so, extract the Xilinx Unified Installer tarball and find the xsetup script and run

``
  bin/xsetup -b ConfigGen
``

In the event that this is not the correct command for this version of xsetup, consult the Vivado manual of the appropriate edition.

