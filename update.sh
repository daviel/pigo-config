#!/bin/bash

CONFIG_DIR="/opt/pigo/pigo-config"

sudo su -

apt update
apt dist-upgrade -y
apt install -y git



if [ ! -d "$CONFIG_DIR" ] ; then
    git clone "https://github.com/daviel/pigo-config" "$CONFIG_DIR"
    cd "$CONFIG_DIR"
    ./install.sh
else
    # Update pigo-config
    cd "$CONFIG_DIR"

    # TODO: implement version comparison
    # CONFIG_VERS=`cat version | tr -d '\n'`
    
    git reset --hard
    git pull
    ./install.sh
fi
