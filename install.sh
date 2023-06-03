#!/bin/bash

CONFIG_DIR="/tmp/pigo-config"

apt update
apt dist-upgrade -y
apt install -y libevdev-dev git python3-pip libcurl4-openssl-dev libopenal1 libmodplug1 libvorbisfile3 libtheora0 libmpg123-0

pip3 install libevdev

mkdir -p /opt/pigo/games


if [ ! -d "$CONFIG_DIR" ] ; then
    git clone "https://github.com/daviel/pigo-config" "$CONFIG_DIR"
fi
if [ ! -d "/opt/pigo/pigogui" ] ; then
    git clone "https://github.com/daviel/pigogui.git" "/opt/pigo/pigogui"
fi
if [ ! -d "/opt/pigo/keymapper" ] ; then
    git clone "https://github.com/daviel/uinput-pigo-mapper.git" "/opt/pigo/keymapper"
fi

CMDLINE=`cat /boot/cmdline.txt | tr -d '\n'`
echo -n $CMDLINE > /boot/cmdline.txt

for i in "loglevel=3" "vt.global_cursor_default=0" "logo.nologo" "quiet"
do
   if grep -q "$i" /boot/cmdline.txt
    then
       echo "found $i"
    else
        echo "not found: $i"
        echo -n " $i" >> /boot/cmdline.txt
    fi
done
echo "" >> /boot/cmdline.txt


cp $CONFIG_DIR/buster.list /etc/apt/sources.list.d/buster.list
cp $CONFIG_DIR/cmdline.txt /boot/cmdline.txt
cp $CONFIG_DIR/config.txt /boot/config.txt
cp $CONFIG_DIR/asound.conf /etc/asound.conf
cp $CONFIG_DIR/wait.conf /etc/systemd/system/dhcpcd.service.d/wait.conf
cp $CONFIG_DIR/fbcp.service /etc/systemd/system/fbcp.service
cp $CONFIG_DIR/lightdisplay.service /etc/systemd/system/lightdisplay.service
cp $CONFIG_DIR/pigogui.service /etc/systemd/system/pigogui.service

rm -rf $CONFIG_DIR

systemctl daemon-reload
systemctl disable getty@tty1
systemctl disable userconfig.service 

systemctl enable pigogui.service
systemctl enable lightdisplay.service
systemctl enable fbcp.service

systemctl stop pigogui.service
systemctl stop lightdisplay.service
systemctl stop fbcp.service
systemctl stop userconfig.service 


sleep 3

wget https://github.com/daviel/SDL-pigo/releases/download/2.0.10-pigo/libSDL2-2.0.so.0.10.0 -O /usr/lib/libSDL2-2.0.so
wget https://github.com/daviel/lvgl/releases/download/v9.0.0-alpha/micropython.13 -O /usr/bin/micropython
wget https://github.com/daviel/fbcp-ili9341-pigo/releases/download/v1.0-pigo/fbcp-ili9341 -O /usr/bin/fbcp

ldconfig
chmod +x /usr/bin/micropython
chmod +x /usr/bin/fbcp

systemctl start pigogui.service
systemctl start lightdisplay.service
systemctl start fbcp.service

apt update
apt install libraspberrypi-dev/oldstable libraspberrypi0/oldstable raspberrypi-bootloader/oldstable wiringpi/oldstable -y --allow-downgrades

apt remove -y userconf-pi triggerhappy firmware-atheros firmware-libertas gcc-10 g++-10 cpp-10 gdb firmware-misc-nonfree manpages-dev git firmware-realtek manpages-dev manpages iso-codes libicu67
apt autoremove -y
apt clean all
