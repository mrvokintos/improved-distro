# vim: set ft=make :

# Restore full KDE Plasma panel layout and launchers from template
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

# Set preferred taskbar launchers (shortcuts)
[group('desktop')]
restore-launchers:
    #!/usr/bin/env bash
    set -euo pipefail
    LAUNCHERS="applications:org.kde.konsole.desktop,preferred://filemanager,applications:brave-browser.desktop,applications:org.telegram.desktop.desktop,applications:discord.desktop,applications:code.desktop,applications:steam.desktop"
    echo "Updating taskbar launchers..."
    qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "
    const allPanels = panels();
    for (let i = 0; i < allPanels.length; ++i) {
        const p = allPanels[i];
        for (const w of p.widgets()) {
            if (w.type === 'org.kde.plasma.icontasks') {
                w.currentConfigGroup = ['General'];
                w.writeConfig('launchers', '$LAUNCHERS'.split(','));
                w.reloadConfig();
            }
        }
    }
    " >/dev/null 2>&1 || true
    echo "Taskbar launchers updated!"

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
