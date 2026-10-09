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
	ckb-next \
	code \
	containerd.io \
	docker-buildx-plugin \
	docker-ce \
	docker-ce-cli \
	docker-compose-plugin \
	firefox \
	firefox-langpacks \
	fontconfig \
	google-carlito-fonts \
	google-crosextra-caladea-fonts \
	jq \
	julietaula-montserrat-fonts \
	liberation-fonts-all \
	portprotonqt \
	sane-backends \
	sane-backends-drivers-scanners \
	skanpage

# Download the four original Times New Roman TTFs directly. Their SHA-256
# hashes match the files in Microsoft's verified Core Fonts archive.
(
	TIMES_WORKDIR=$(mktemp -d)
	trap 'rm -rf "${TIMES_WORKDIR}"' EXIT
	TIMES_FONT_BASE='https://raw.githubusercontent.com/misuchiru03/font-times-new-roman/78a017b4a19ae3063eedbfa36c548709295cd67a'
	while read -r source_file font checksum; do
		curl --location --fail --silent --show-error --retry 3 --retry-all-errors \
			--output "${TIMES_WORKDIR}/${font}" \
			"${TIMES_FONT_BASE}/${source_file}"
		printf '%s  %s\n' "${checksum}" "${TIMES_WORKDIR}/${font}" | \
			sha256sum --check --strict
		install -Dm0644 "${TIMES_WORKDIR}/${font}" \
			"/usr/share/fonts/microsoft-core/${font}"
	done <<'EOF'
Times%20New%20Roman.ttf times.ttf 4e98adeff8ccc8ef4e3ece8d4547e288ff85fdc9c7ca711a4599c234874bbe86
Times%20New%20Roman%20-%20Bold.ttf timesbd.ttf 4357b63cef20c01661a53c5dae70ffd20cb4765503aaed6d38b17a57c5a90bff
Times%20New%20Roman%20-%20Italic.ttf timesi.ttf c25ae529b4cecdbca148b6ccb862ee0abad770af8b1fd29c8dba619d1b8da78a
Times%20New%20Roman%20-%20Bold%20Italic.ttf timesbi.ttf 192e1b0d18e90334e999a99f8c32808d6a2e74b3698b8cd90c943c2249a46549
EOF
	fc-scan --format '%{family}\n' \
		/usr/share/fonts/microsoft-core/times.ttf | grep -qxF 'Times New Roman'
	fc-cache -f /usr/share/fonts/microsoft-core
)

# The daemon talks to supported Corsair devices and is required by the GUI.
systemctl enable ckb-next-daemon.service
systemctl enable docker.socket

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
test -f /opt/Throne/ThroneCore
test -f /usr/share/applications/Throne.desktop

# ThroneCore requires root privileges (SUID) to manage TUN interfaces and routing.
# In an immutable image (/opt is read-only at runtime), Throne cannot set SUID at runtime.
chown root:root /opt/Throne/ThroneCore
chmod 4755 /opt/Throne/ThroneCore
test -u /opt/Throne/ThroneCore

# Register Throne's bundled icon with the desktop icon theme. The upstream RPM
# references the image in /opt directly, which Plasma does not reliably match
# to the running application.
install -Dm0644 \
	/opt/Throne/Throne.png \
	/usr/share/icons/hicolor/512x512/apps/throne.png
sed -i 's|^Icon=.*$|Icon=throne|' /usr/share/applications/Throne.desktop
grep -q '^StartupWMClass=' /usr/share/applications/Throne.desktop || \
	sed -i '/^Icon=/a StartupWMClass=Throne' \
		/usr/share/applications/Throne.desktop
if command -v gtk-update-icon-cache >/dev/null; then
	gtk-update-icon-cache --force /usr/share/icons/hicolor
fi
grep -qxF 'Icon=throne' /usr/share/applications/Throne.desktop
test -f /usr/share/icons/hicolor/512x512/apps/throne.png

# This image uses only the Epson L355 scanner, so do not probe unrelated SANE
# backends every time an application enumerates devices.
printf 'epson2\n' > /etc/sane.d/dll.conf

# The epson2 backend expects only the host after "net" and uses its protocol
# port internally; appending a port makes it resolve an invalid hostname.
sed -i \
	's/^[[:space:]]*net[[:space:]]\+autodiscovery[[:space:]]*$/# net autodiscovery disabled/' \
	/etc/sane.d/epson2.conf
grep -qxF 'net 192.168.2.138' /etc/sane.d/epson2.conf || \
	printf '\nnet 192.168.2.138\n' >> /etc/sane.d/epson2.conf

# The same scanner is also advertised over WSD. Disable the generic AirScan
# backend to avoid a duplicate device and its slow network discovery pass.
if [[ -f /etc/sane.d/dll.d/airscan ]]; then
	sed -i 's/^[[:space:]]*airscan[[:space:]]*$/# airscan disabled/' \
		/etc/sane.d/dll.d/airscan
fi

dnf5 -y copr disable boria138/portproton
dnf5 config-manager setopt \
	brave-browser.enabled=0 \
	code.enabled=0 \
	docker-ce-stable.enabled=0

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
