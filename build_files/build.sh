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

# Epson gates these packages behind an interactive license page, so keep the
# exact vendor RPMs in the build context and verify them before installation.
EPSON_RPM_DIR=/ctx/rpms
(
	cd "${EPSON_RPM_DIR}"
	sha256sum --check --strict <<'EOF'
e8136c4ac38c26e8f908084428f28ab3f6eedba4c3993d16b7879d26844d15fa  epson-inkjet-printer-201207w-1.0.2-1.x86_64.rpm
58f992ea28f4b2b010ba0a4b1bf213deeabf7ad02cd9927de19db0676c76d489  epson-printer-utility-1.2.3-1.x86_64.rpm
EOF
)

# The printer packages contain RPM digests and can be handled by DNF.
dnf5 install -y \
	"${EPSON_RPM_DIR}"/epson-inkjet-printer-201207w-1.0.2-1.x86_64.rpm \
	"${EPSON_RPM_DIR}"/epson-printer-utility-1.2.3-1.x86_64.rpm

# Fedora packages and applications from the repository files in
# system_files/etc/yum.repos.d/.
dnf5 install -y \
	brave-browser \
	brave-origin \
	code \
	firefox \
	firefox-langpacks \
	jq \
	portprotonqt \
	sane-backends \
	sane-backends-drivers-scanners \
	skanpage

# GitHub's latest-release endpoint excludes drafts and pre-releases. Select the
# official Fedora RPM and verify it against the digest published for the asset.
THRONE_RELEASE=$(mktemp)
THRONE_RPM=$(mktemp --suffix=.rpm)
curl --location --fail --silent --show-error --retry 3 --retry-all-errors \
	--header 'Accept: application/vnd.github+json' \
	--header 'X-GitHub-Api-Version: 2022-11-28' \
	--output "${THRONE_RELEASE}" \
	'https://api.github.com/repos/throneproj/Throne/releases/latest'
mapfile -t THRONE_ASSET < <(
	jq -er '
		[.assets[] | select(.name | endswith("-fedora-amd64-system-qt.rpm"))]
		| if length == 1 then .[0] else error("expected exactly one Fedora AMD64 system-Qt RPM") end
		| .browser_download_url, .digest
	' "${THRONE_RELEASE}"
)
rm -f "${THRONE_RELEASE}"
[[ ${#THRONE_ASSET[@]} -eq 2 ]]
[[ ${THRONE_ASSET[0]} == https://github.com/throneproj/Throne/releases/download/* ]]
[[ ${THRONE_ASSET[1]} == sha256:* ]]
curl --location --fail --silent --show-error --retry 3 --retry-all-errors \
	--output "${THRONE_RPM}" \
	"${THRONE_ASSET[0]}"
printf '%s  %s\n' "${THRONE_ASSET[1]#sha256:}" "${THRONE_RPM}" | \
	sha256sum --check --strict
dnf5 install -y "${THRONE_RPM}"
rm -f "${THRONE_RPM}"
test -x /opt/Throne/Throne
test -f /usr/share/applications/Throne.desktop

# The Epson L355 scanner speaks ESC/I over the network on port 1865.
grep -qxF 'net 192.168.2.138 1865' /etc/sane.d/epson2.conf || \
	printf '\nnet 192.168.2.138 1865\n' >> /etc/sane.d/epson2.conf

dnf5 -y copr disable boria138/portproton
dnf5 config-manager setopt \
	brave-browser.enabled=0 \
	code.enabled=0

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

### Configure Bazzite's system Flatpaks

if [[ -f /usr/share/ublue-os/bazzite/flatpak/install ]]; then
	sed -i '/^org\.mozilla\.firefox$/d' \
		/usr/share/ublue-os/bazzite/flatpak/install
	grep -qxF 'org.telegram.desktop' \
		/usr/share/ublue-os/bazzite/flatpak/install || \
		echo 'org.telegram.desktop' >> \
		/usr/share/ublue-os/bazzite/flatpak/install
fi
