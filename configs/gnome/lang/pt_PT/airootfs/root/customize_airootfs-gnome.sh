#!/bin/bash

set -e -u

# Run releng's defaults
/root/customize_airootfs.sh

# pt_PT.UTF8 locales
sed -i 's/#\(pt_PT\.UTF-8\)/\1/' /etc/locale.gen
locale-gen

# Portugal, Lisbon timezone
ln -sf /usr/share/zoneinfo/Europe/Lisbon /etc/localtime

# nsswitch.conf settings
# * Avahi : add 'mdns_minimal'
# * Winbind : add 'wins'
sed -i '/^hosts:/ {
        s/\(resolve\)/mdns_minimal \[NOTFOUND=return\] \1/
        s/\(dns\)$/\1 wins/ }' /etc/nsswitch.conf

# Test nvidia package installed
# Nvidia GPU proprietary driver setup
if $(pacman -Qsq '^nvidia$' > /dev/null 2>&1); then
    sed -i 's|^#\(display-setup-script=\)$|\1/etc/lightdm/display_setup.sh|' /etc/lightdm/lightdm.conf
fi

# Lightdm display-manager
# * live user autologin
# * Adwaita theme
# * background color
sed -i 's/^#\(autologin-user=\)$/\1live/
        s/^#\(autologin-session=\)$/\1gnome/' /etc/lightdm/lightdm.conf
sed -i 's/^#\(background=\)$/\1#204a87/
        s/^#\(theme-name=\)$/\1Adwaita/
        s/^#\(icon-theme-name=\)$/\1Adwaita/' /etc/lightdm/lightdm-gtk-greeter.conf

# Force wayland session type (related to Nvidia proprietary driver)
sed -i 's|^\(Exec=\).*|\1env XDG_SESSION_TYPE=wayland /usr/bin/gnome-session|' /usr/share/xsessions/gnome.desktop

# Remove duplicate from lightdm sessions type list
mv /usr/share/wayland-sessions/gnome.desktop{,.duplicate}

# missing link pointing to default vncviewer
ln -s /usr/bin/gvncviewer /usr/local/bin/vncviewer

# Enable service when available
{ [[ -e /usr/lib/systemd/system/acpid.service                ]] && systemctl enable acpid.service;
  [[ -e /usr/lib/systemd/system/avahi-dnsconfd.service       ]] && systemctl enable avahi-dnsconfd.service;
  [[ -e /usr/lib/systemd/system/bluetooth.service            ]] && systemctl enable bluetooth.service;
  [[ -e /usr/lib/systemd/system/NetworkManager.service       ]] && systemctl enable NetworkManager.service;
  [[ -e /usr/lib/systemd/system/nmb.service                  ]] && systemctl enable nmb.service;
  [[ -e /usr/lib/systemd/system/org.cups.cupsd.service       ]] && systemctl enable org.cups.cupsd.service;
  [[ -e /usr/lib/systemd/system/smb.service                  ]] && systemctl enable smb.service;
  [[ -e /usr/lib/systemd/system/systemd-timesyncd.service    ]] && systemctl enable systemd-timesyncd.service;
  [[ -e /usr/lib/systemd/system/winbind.service              ]] && systemctl enable winbind.service;
} > /dev/null 2>&1

# Set lightdm display-manager
# Using lightdm-plymouth when available
if [[ -e /usr/lib/systemd/system/lightdm-plymouth.service ]]; then
    ln -s /usr/lib/systemd/system/lightdm-plymouth.service /etc/systemd/system/display-manager.service
else
    ln -s /usr/lib/systemd/system/lightdm.service /etc/systemd/system/display-manager.service
fi

# Add live user
# * groups member
# * user without password
# * sudo no password settings
useradd -m -G "adm,audio,floppy,log,network,rfkill,scanner,storage,optical,power,sys,video,wheel" -s /bin/zsh live
sed -i 's/^\(live:\)!:/\1:/' /etc/shadow
sed -i 's/^#\s\(%wheel\s.*NOPASSWD\)/\1/' /etc/sudoers

# Create autologin group
# add live to autologin group
groupadd -r autologin
gpasswd -a live autologin
