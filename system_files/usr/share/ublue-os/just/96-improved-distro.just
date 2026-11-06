# vim: set ft=make :

# Restore the KDE Plasma panel layout and taskbar launchers shipped with the image
[group('desktop')]
restore-panels:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Restoring KDE Plasma panels and launchers from template..."
    mkdir -p "$HOME/.config"
    cp -f /usr/share/ublue-os/plasma/plasma-org.kde.plasma.desktop-appletsrc "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
    cp -f /usr/share/ublue-os/plasma/plasmashellrc "$HOME/.config/plasmashellrc"
    if systemctl --user is-active plasma-plasmashell.service >/dev/null 2>&1; then
        echo "Reloading plasmashell..."
        systemctl --user restart plasma-plasmashell.service
    fi
    echo "Panels and taskbar launchers successfully restored!"

# Add current user to docker group
[group('system')]
docker-group:
    #!/usr/bin/env bash
    if ! grep -q "^docker:" /etc/group; then
        echo "Appending docker to /etc/group"
        grep "^docker:" /usr/lib/group | sudo tee -a /etc/group > /dev/null
    fi
    sudo usermod -aG docker "$USER"
    echo "User $USER added to docker group. Relog or reboot to apply changes."
