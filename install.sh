#!/bin/bash

CONFIG_DIR="$CONFIG_DIR"

apt update
apt install libevdev-dev git python3-pip libraspberrypi-dev/oldstable libraspberrypi0/oldstable raspberrypi-bootloader/oldstable wiringpi/oldstable -y --allow-downgrades
apt remove userconf-pi triggerhappy -y

mkdir -p /opt/pigo/games


git clone https://github.com/daviel/pigo-config $CONFIG_DIR
git clone https://github.com/daviel/uinput-pigo-mapper.git /opt/pigo/keymapper
git clone https://github.com/daviel/pigogui.git /opt/pigo/pigogui


wget https://github.com/daviel/SDL-pigo/releases/download/2.0.10-pigo/libSDL2-2.0.so.0.10.0 -O /usr/lib/libSDL2-2.0.so
wget https://github.com/daviel/lv_binding_micropython/releases/download/v9.0.0-pigo/micropython -O /usr/bin/micropython
wget https://github.com/daviel/fbcp-ili9341-pigo/releases/download/v1.0-pigo/fbcp-ili9341 -O /usr/bin/fbcp


cp $CONFIG_DIR/buster.list /etc/apt/sources.list.d/buster.list
cp $CONFIG_DIR/cmdline.txt /boot/cmdline.txt
cp $CONFIG_DIR/config.txt /boot/config.txt
cp $CONFIG_DIR/asound.conf /etc/asound.conf
cp $CONFIG_DIR/wait.conf /etc/systemd/system/dhcpcd.service.d/wait.conf
cp $CONFIG_DIR/fbcp.service /etc/systemd/system/fbcp.service
cp $CONFIG_DIR/lightdisplay.service /etc/systemd/system/lightdisplay.service
cp $CONFIG_DIR/pigogui.service /etc/systemd/system/pigogui.service


ldconfig
chmod +x /usr/bin/micropython
chmod +x /usr/bin/fbcp


systemctl daemon-reload
systemctl disable getty@tty1
systemctl enable pigogui.service
systemctl enable lightdisplay.service
systemctl enable fbcp.service


apt autoremove -y
apt clean
rm -rf $CONFIG_DIR