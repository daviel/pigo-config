#!/bin/bash -e

# Proper root escalation: re-executes the whole script as root if needed.
# Works both on a running Pi (as user pigo) and in pi-gen chroot (already root).
if [ "$(id -u)" != "0" ]; then
    exec sudo bash "$0" "$@"
fi

CONFIG_DIR="/opt/pigo/pigo-config"
PIGOGUI_DIR="/opt/pigo/pigogui"
KEYMAPPER_DIR="/opt/pigo/keymapper"

# ── Pakete ────────────────────────────────────────────────────────────────────

apt-get update
apt-get dist-upgrade -y
apt-get install -y \
    libevdev-dev git python3-pip libcurl4 \
    libopenal1 libmodplug1 libvorbisfile3 libtheora0 \
    python3-libevdev wget sway seatd openssh-server \
    device-tree-compiler \
    libsdl2-2.0-0 \
    mpg123 \
    pipewire-pulse \
    network-manager
apt-get --fix-broken install -y

# ── Verzeichnisse ─────────────────────────────────────────────────────────────

mkdir -p /opt/pigo/games
mkdir -p /home/pigo/.config/sway
mkdir -p /home/pigo/.config/systemd/user/default.target.wants
mkdir -p /home/pigo/.config/systemd/user/sway.service.wants

# ── Benutzer ──────────────────────────────────────────────────────────────────

usermod -aG video,input,audio,tty,seat pigo

# seatd aktivieren: ermöglicht Sway KMS/DRM-Zugriff ohne getty-VT-Session
systemctl enable seatd.service

# loginctl enable-linger benötigt einen laufenden systemd-Bus.
# Direkt die Linger-Datei anlegen – identisches Ergebnis.
mkdir -p /var/lib/systemd/linger
touch /var/lib/systemd/linger/pigo

# ── Repos klonen / aktualisieren ──────────────────────────────────────────────

if [ ! -d "$PIGOGUI_DIR" ]; then
    git clone "https://github.com/daviel/pigogui.git" "$PIGOGUI_DIR"
else
    cd "$PIGOGUI_DIR"
    git reset --hard
    git pull
fi

if [ ! -d "$KEYMAPPER_DIR" ]; then
    git clone "https://github.com/daviel/uinput-pigo-mapper.git" "$KEYMAPPER_DIR"
else
    cd "$KEYMAPPER_DIR"
    git reset --hard
    git pull
fi

# ── Boot-Konfiguration ────────────────────────────────────────────────────────

# Konsole von tty1 auf tty3 verlegen (Sway übernimmt tty3)
sed -i 's/console=tty1/console=tty3/g' /boot/firmware/cmdline.txt

# Stille Boot-Parameter ergänzen, falls noch nicht vorhanden
for param in "loglevel=0" "vt.global_cursor_default=0" "logo.nologo" "quiet" "splash" "console=tty3"; do
    if grep -q "$param" /boot/firmware/cmdline.txt; then
        echo "found: $param"
    else
        echo "adding: $param"
        sed -i "s/$/ $param/" /boot/firmware/cmdline.txt
    fi
done

# ILI9341 SPI-Display-Overlay kompilieren und installieren
cp "$CONFIG_DIR/ili9341-modern.dts" /boot/firmware/overlays/ili9341-modern.dts
dtc -@ -I dts -O dtb \
    -o /boot/firmware/overlays/ili9341-modern.dtbo \
       /boot/firmware/overlays/ili9341-modern.dts

# Konfigurationsdateien kopieren
cp "$CONFIG_DIR/config.txt"          /boot/firmware/config.txt
cp "$CONFIG_DIR/asound.conf"         /etc/asound.conf

# uinput: Modul beim Boot laden + Gruppe input Zugriff gewähren (für Keymapper)
echo "uinput" > /etc/modules-load.d/uinput.conf
cp "$CONFIG_DIR/99-uinput.rules"     /etc/udev/rules.d/99-uinput.rules

# ── Systemd-Units ─────────────────────────────────────────────────────────────

cp "$CONFIG_DIR/lightdisplay.service" /etc/systemd/system/lightdisplay.service
cp "$CONFIG_DIR/pigogui.service"      /home/pigo/.config/systemd/user/pigogui.service
cp "$CONFIG_DIR/sway.service"         /home/pigo/.config/systemd/user/sway.service
cp "$CONFIG_DIR/sway.config"          /home/pigo/.config/sway/config

chown -R pigo:pigo /home/pigo/.config
chown -R pigo:pigo /opt/pigo

# daemon-reload benötigt einen laufenden systemd – im pi-gen-chroot nicht verfügbar
systemctl daemon-reload 2>/dev/null || true

# Unerwünschte getty-/Setup-Services deaktivieren
systemctl disable getty@tty1.service     2>/dev/null || true
systemctl disable userconfig.service     2>/dev/null || true
systemctl disable keyboard-setup.service 2>/dev/null || true
systemctl disable console-setup.service  2>/dev/null || true

# systemctl --user benötigt einen User-Session-Bus – Symlinks direkt setzen
ln -sf /home/pigo/.config/systemd/user/sway.service \
       /home/pigo/.config/systemd/user/default.target.wants/sway.service
ln -sf /home/pigo/.config/systemd/user/pigogui.service \
       /home/pigo/.config/systemd/user/sway.service.wants/pigogui.service

systemctl enable lightdisplay.service

# ── Binaries ──────────────────────────────────────────────────────────────────

# micropython (LVGL-Build)
rm -f /usr/bin/micropython
wget https://github.com/daviel/lvgl/releases/download/v9.3.0-arm64/micropython \
    -O /usr/bin/micropython
chmod +x /usr/bin/micropython
ldconfig

# WiringPi – Download nach /tmp, danach aufräumen
wget https://github.com/WiringPi/WiringPi/releases/download/3.18/wiringpi_3.18_arm64.deb \
    -O /tmp/wiringpi.deb
dpkg -i /tmp/wiringpi.deb
rm /tmp/wiringpi.deb

# Services starten (nur bei laufendem systemd; im pi-gen-chroot kein Daemon)
systemctl restart lightdisplay.service 2>/dev/null || true

# ── Aufräumen: Pakete ─────────────────────────────────────────────────────────

apt-get purge -y \
    `# Firmware für nicht vorhandene Hardware` \
    triggerhappy \
    firmware-atheros firmware-libertas firmware-realtek firmware-misc-nonfree \
    \
    `# Compiler / Debug-Tools` \
    gcc-12 g++-12 cpp-12 gcc-13 g++-13 cpp-13 \
    gdb strace \
    \
    `# Entwicklungs-Tools` \
    pkg-config python3-venv mkvtoolnix \
    \
    `# Dokumentation` \
    manpages manpages-dev iso-codes \
    \
    `# Nicht vorhandene Hardware` \
    v4l-utils fbset pciutils \
    rpi-keyboard-config rpi-keyboard-fw-update \
    usb-modeswitch libmtp-runtime \
    \
    `# Netzwerk-Tools (NetworkManager übernimmt das)` \
    net-tools wireless-tools ethtool ssh-import-id \
    \
    `# Nicht verwendete Scripting-Runtimes` \
    lua5.1 luajit \
    \
    `# System-Management nicht benötigt` \
    apt-listchanges udisks2 rpi-update rpi-connect-lite \
    raspi-config parted debconf-utils \
    \
    `# Sonstiges` \
    ed ncdu nfs-common \
    2>/dev/null || true

apt-get autoremove --purge -y
apt-get clean

# ── Aufräumen: Dateisystem ────────────────────────────────────────────────────

# Paket-Dokumentation (Copyright-Dateien bleiben erhalten)
find /usr/share/doc -depth -type f ! -name 'copyright' -delete 2>/dev/null || true
find /usr/share/doc -empty -type d -delete                  2>/dev/null || true

# Locale-Daten auf Deutsch und Englisch reduzieren
find /usr/share/locale -mindepth 1 -maxdepth 1 \
    ! -name 'de' ! -name 'de_DE' ! -name 'en' ! -name 'en_US' \
    -exec rm -rf {} + 2>/dev/null || true

# Python-Bytecode-Cache entfernen
find /usr -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true

# systemd-Journal auf 20 MB begrenzen
mkdir -p /etc/systemd/journald.conf.d /var/log/journal
printf '[Journal]\nStorage=persistent\nSystemMaxUse=20M\nRuntimeMaxUse=10M\nCompress=yes\n' \
    > /etc/systemd/journald.conf.d/size.conf

# ── Sysctl ────────────────────────────────────────────────────────────────────

touch /etc/sysctl.conf
if grep -q "^vm.swappiness" /etc/sysctl.conf; then
    echo "found vm.swappiness"
else
    echo "vm.swappiness=10" >> /etc/sysctl.conf
fi

# ── SSH ───────────────────────────────────────────────────────────────────────

# Host-Keys erzeugen (werden in pi-gen-Images beim ersten Boot neu generiert)
dpkg-reconfigure openssh-server 2>/dev/null || true
ssh-keygen -A
