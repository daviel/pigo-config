#!/bin/bash

sudo su -

CONFIG_DIR="/opt/pigo/pigo-config"
PIGOGUI_DIR="/opt/pigo/pigogui"
KEYMAPPER_DIR="/opt/pigo/keymapper"

apt update
apt dist-upgrade -y
apt install -y libevdev-dev git python3-pip libcurl4-openssl-dev libopenal1 libmodplug1 libvorbisfile3 libtheora0 python3-libevdev wget sway seatd openssh-server
apt --fix-broken install -y

mkdir -p /opt/pigo/games
mkdir -p /home/pigo/.config/sway
mkdir -p /home/pigo/.config/systemd/user/

usermod -aG video,input,audio,tty pigo
loginctl enable-linger pigo

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

cp $CONFIG_DIR/ili9341-modern.dts /boot/firmware/overlays/ili9341-modern.dts
dtc -@ -I dts -O dtb -o /boot/firmware/overlays/ili9341-modern.dtbo /boot/firmware/overlays/ili9341-modern.dts

cp $CONFIG_DIR/sway.service /home/pigo/.config/systemd/user/sway.service
cp $CONFIG_DIR/sway.config /home/pigo/.config/sway/config
cp $CONFIG_DIR/config.txt /boot/firmware/config.txt
cp $CONFIG_DIR/asound.conf /etc/asound.conf
cp $CONFIG_DIR/lightdisplay.service /etc/systemd/system/lightdisplay.service
cp $CONFIG_DIR/pigogui.service /etc/systemd/system/pigogui.service

systemctl daemon-reload
systemctl --user daemon-reload

systemctl disable getty@tty1.service
systemctl disable userconfig.service
systemctl disable keyboard-setup.service
systemctl disable console-setup.service
systemctl --user enable sway

systemctl enable pigogui.service
systemctl enable lightdisplay.service

rm -f /usr/bin/micropython
wget https://github.com/daviel/lvgl/releases/download/v9.3.0/micropython -O /usr/bin/micropython

ldconfig
chmod +x /usr/bin/micropython

systemctl restart pigogui.service
systemctl restart lightdisplay.service

# wiring pi
wget https://github.com/WiringPi/WiringPi/releases/download/3.18/wiringpi_3.18_arm64.deb
dpkg -i wiringpi_3.18_arm64.deb

# cleanup
apt remove -y triggerhappy firmware-atheros firmware-libertas gcc-12 g++-12 cpp-12 gdb firmware-misc-nonfree manpages-dev firmware-realtek manpages-dev manpages iso-codes nfs-common
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

# for SSH access
dpkg-reconfigure openssh-server
ssh-keygen -A
