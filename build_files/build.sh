#!/bin/bash

set -ouex pipefail

# Copy the contents of system_files/ of the git repo to /
cp -avf "/ctx/system_files"/. /

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/43/x86_64/repoview/index.html&protocol=https&redirect=1

# Remove Waydroid itself. Bazzite's helper files are not owned by the
# Waydroid RPM, so they are cleaned up separately below.
dnf5 remove -y waydroid

# PortProtonQt is distributed through COPR. Keep the repository disabled in
# the finished image; it is enabled again on every image build.
dnf5 -y copr enable boria138/portproton

# Install the latest official Discord RPM.
DISCORD_RPM=$(mktemp --suffix=.rpm)
curl --location --fail --silent --show-error --retry 3 \
	--output "${DISCORD_RPM}" \
	'https://discord.com/api/download?platform=linux&format=rpm'
dnf5 install -y "${DISCORD_RPM}"
rm -f "${DISCORD_RPM}"

# Fedora packages and applications from the repository files in
# system_files/etc/yum.repos.d/.
dnf5 install -y \
	brave-browser \
	code \
	firefox \
	firefox-langpacks \
	portprotonqt \
	throne

dnf5 -y copr disable boria138/portproton
dnf5 config-manager setopt \
	brave-browser.enabled=0 \
	code.enabled=0 \
	throne-repo.enabled=0

### Remove Bazzite's Waydroid integration

sed -i '\|82-bazzite-waydroid.just|d' /usr/share/ublue-os/justfile

if [[ -f /usr/share/yafti/yafti.yml ]]; then
	sed -i \
		'/^      - id: "waydroid"$/,/^  - title:/{/^  - title:/!d;}' \
		/usr/share/yafti/yafti.yml
fi

rm -f \
	/etc/default/waydroid-launcher \
	/usr/bin/waydroid-choose-gpu \
	/usr/bin/waydroid-launcher \
	/usr/libexec/waydroid-container-restart \
	/usr/libexec/waydroid-container-start \
	/usr/libexec/waydroid-container-stop \
	/usr/libexec/waydroid-fix-controllers \
	/usr/share/applications/waydroid-container-restart.desktop \
	/usr/share/polkit-1/actions/org.bazzite.waydroid.policy \
	/usr/share/polkit-1/rules.d/30-waydroid.rules \
	/usr/share/ublue-os/just/82-bazzite-waydroid.just \
	/usr/share/ublue-os/motd/tips/20-bazzite.md

rm -rf \
	/usr/lib/waydroid \
	/usr/share/ublue-os/waydroid

### Prefer Fedora's Firefox RPM over Bazzite's default Firefox Flatpak

if [[ -f /usr/share/ublue-os/bazzite/flatpak/install ]]; then
	sed -i '/^org\.mozilla\.firefox$/d' \
		/usr/share/ublue-os/bazzite/flatpak/install
fi
