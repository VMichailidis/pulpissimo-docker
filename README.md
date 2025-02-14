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
make start
``

# Vivado

If you wish to use another vivado version, you need to change the Dockerfile to point to the correct installer and potentially generate a valid a new configuration file for the unattended installer.
To do so, extract the Xilinx Unified Installer tarball and find the xsetup script and run

``
  bin/xsetup -b ConfigGen
``

In the event that this is not the correct command for this version of xsetup, consult the Vivado manual of the appropriate edition.

