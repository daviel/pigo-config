#!/bin/bash

sudo su -

CONFIG_DIR="/opt/pigo/pigo-config"
PIGOGUI_DIR="/opt/pigo/pigogui"
KEYMAPPER_DIR="/opt/pigo/keymapper"

apt update
apt dist-upgrade -y
apt install -y libevdev-dev git python3-pip libcurl4-openssl-dev libopenal1 libmodplug1 libvorbisfile3 libtheora0 libmpg123-0 python3-libevdev

mkdir -p /opt/pigo/games


if [ ! -d "/opt/pigo/pigogui" ] ; then
    git clone "https://github.com/daviel/pigogui.git" "$PIGOGUI_DIR"
else
    # update pigogui
    cd "$PIGOGUI_DIR"
    git reset --hard
    git pull
fi

if [ ! -d "/opt/pigo/keymapper" ] ; then
    git clone "https://github.com/daviel/uinput-pigo-mapper.git" "$KEYMAPPER_DIR"
else
    # update keymapper
    cd "$KEYMAPPER_DIR"
    git reset --hard
    git pull
fi

sed -i 's/console=tty1/console=tty3/g' /boot/firmware/cmdline.txt
CMDLINE=`cat /boot/firmware/cmdline.txt | tr -d '\n'`
echo -n $CMDLINE > /boot/firmware/cmdline.txt

for i in "loglevel=0" "vt.global_cursor_default=0" "logo.nologo" "quiet" "splash" "console=tty3"
do
   if grep -q "$i" /boot/firmware/cmdline.txt
    then
       echo "found $i"
    else
        echo "not found: $i"
        echo -n " $i" >> /boot/firmware/cmdline.txt
    fi
done
echo "" >> /boot/firmware/cmdline.txt


cp $CONFIG_DIR/buster.list /etc/apt/sources.list.d/buster.list
cp $CONFIG_DIR/config.txt /boot/firmware/config.txt
cp $CONFIG_DIR/asound.conf /etc/asound.conf
cp $CONFIG_DIR/wait.conf /etc/systemd/system/dhcpcd.service.d/wait.conf
cp $CONFIG_DIR/fbcp.service /etc/systemd/system/fbcp.service
cp $CONFIG_DIR/lightdisplay.service /etc/systemd/system/lightdisplay.service
cp $CONFIG_DIR/pigogui.service /etc/systemd/system/pigogui.service

systemctl daemon-reload
systemctl disable getty@tty1.service
systemctl disable userconfig.service
systemctl disable hciuart.service
systemctl disable keyboard-setup.service
systemctl disable console-setup.service
systemctl disable bluetooth.service

systemctl enable pigogui.service
systemctl enable lightdisplay.service
systemctl enable fbcp.service

systemctl stop pigogui.service
systemctl stop lightdisplay.service
systemctl stop fbcp.service
systemctl stop userconfig.service 


rm -f /usr/lib/libSDL2*
rm -f /lib/arm-linux-gnueabihf/libSDL2*

wget https://github.com/daviel/SDL-pigo/releases/download/2.0.10-pigo/libSDL2-2.0.so.0.10.0 -O /usr/lib/libSDL2-2.0.so
cp /usr/lib/libSDL2-2.0.so /lib/arm-linux-gnueabihf/libSDL2-2.0.so.0.10.0

rm -f /usr/bin/micropython
rm -f /usr/bin/fbcp

wget https://github.com/daviel/lvgl/releases/download/v9.2.0/micropython -O /usr/bin/micropython
wget https://github.com/daviel/fbcp-ili9341-pigo/releases/download/v1.0-pigo/fbcp-ili9341 -O /usr/bin/fbcp



ldconfig
chmod +x /usr/bin/micropython
chmod +x /usr/bin/fbcp

systemctl restart pigogui.service
systemctl restart lightdisplay.service
systemctl restart fbcp.service

apt update
apt install libraspberrypi-dev/buster libraspberrypi0/buster raspberrypi-bootloader/buster wiringpi -y --allow-downgrades

apt remove -y triggerhappy firmware-atheros firmware-libertas gcc-12 g++-12 cpp-12 gdb firmware-misc-nonfree manpages-dev firmware-realtek manpages-dev manpages iso-codes libicu* nfs-common
apt autoremove -y
apt clean all


# set swappiness
SYSCTL=`cat /etc/sysctl.conf | tr -d '\n'`
echo -n $SYSCTL > /etc/sysctl.conf

for i in "vm.swappiness=10"
do
   if grep -q "$i" /etc/sysctl.conf
    then
       echo "found $i"
    else
        echo "not found $i adding it to /etc/sysctl.conf"
        echo -n " $i" >> /etc/sysctl.conf
    fi
done
echo "" >> /etc/sysctl.conf

DPHYS_SWAPFILE=`cat /etc/dphys-swapfile | tr -d '\n'`
echo -n $DPHYS_SWAPFILE > /etc/dphys-swapfile

for i in "CONF_SWAPSIZE=512"
do
   if grep -q "$i" /etc/dphys-swapfile
    then
       echo "found $i"
    else
        echo "not found $i adding it to /etc/dphys-swapfile"
        echo -n " $i" >> /etc/dphys-swapfile
    fi
done
echo "" >> /etc/dphys-swapfile
