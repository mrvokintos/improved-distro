# improved-distro

`improved-distro` is a personal, signed [bootc](https://bootc-dev.github.io/bootc/) image derived from the stable NVIDIA Open edition of [Bazzite](https://bazzite.gg/). It keeps the regular Bazzite desktop and gaming stack while changing a small set of system applications and hardware defaults.

The published image is:

```text
ghcr.io/mrvokintos/improved-distro:latest
```

This image is intended for a KDE desktop with an NVIDIA GPU supported by Bazzite's open NVIDIA kernel modules. It is not a general-purpose replacement for every Bazzite hardware variant.

## Changes from Bazzite

### Added to the system image

- Brave Browser from the official Brave RPM repository
- Visual Studio Code from the official Microsoft RPM repository
- Discord from the official Discord RPM download
- Firefox and Firefox language packs from Fedora RPM repositories
- PortProtonQt from the `boria138/portproton` COPR
- Throne from the Parhelia repository
- Epson Inkjet Printer Driver `201207w`
- Epson Printer Utility
- Epson Image Scan!, scanner data, and network scanner support

Telegram Desktop is installed as a system Flatpak from Flathub.

### Removed or changed

- Waydroid and Bazzite's Waydroid integration are removed.
- The Firefox Flatpak is removed from Bazzite's default Flatpak installation list because Firefox is provided as an RPM.
- A libinput quirk disables high-resolution wheel events for the Logitech G502 X LS (`046d:409f`) to work around inconsistent scrolling.
- `/opt` is part of the immutable image so RPM applications can safely install files there.

The external RPM repositories are enabled only while the image is being built and are disabled in the completed image. Vendored Epson packages are verified against SHA-256 checksums before installation.

## Switching from Bazzite

Only switch after the latest GitHub Actions build has completed successfully. Save any important data before changing operating-system images, even though bootc is designed to preserve system state across a switch.

```bash
sudo bootc switch ghcr.io/mrvokintos/improved-distro:latest
sudo systemctl reboot
```

After rebooting, confirm the active deployment:

```bash
sudo bootc status
```

User data in `/var`—including `/var/home`—is preserved. Local configuration in `/etc` is merged into the new deployment. Files manually placed in immutable system directories such as `/usr` are not persistent and are replaced by the image.

Layered packages and custom system modifications may conflict with the new image. Remove unnecessary RPM layering before switching and keep a backup of irreplaceable files.

## Rollback and return to Bazzite

bootc keeps the previous deployment as a rollback option. To make the rollback deployment the default, use:

```bash
sudo bootc rollback
sudo systemctl reboot
```

You can also return explicitly to the upstream image used by this project:

```bash
sudo bootc switch ghcr.io/ublue-os/bazzite-nvidia-open:stable
sudo systemctl reboot
```

If the new deployment does not boot, select the previous deployment from the bootloader menu.

## Updates

Updates are automatic end to end:

1. Renovate detects a new digest for `bazzite-nvidia-open:stable`.
2. Renovate opens a pull request containing the new pinned digest.
3. GitHub Actions builds and validates the complete customized image.
4. Renovate merges the pull request only after the checks pass.
5. GitHub Actions signs and publishes the new `latest` image to GHCR.
6. The normal Bazzite/bootc update mechanism can deploy that new image on installed systems.

If validation fails, the update is not merged and the previously published image remains available. Renovate configuration is stored in [`.github/renovate.json5`](./.github/renovate.json5).

To check for and stage an update manually:

```bash
sudo bootc update
```

## Image verification

Published images are signed with Cosign. The public key is committed as [`cosign.pub`](./cosign.pub):

```bash
cosign verify \
  --key cosign.pub \
  ghcr.io/mrvokintos/improved-distro:latest
```

## Repository layout

- [`Containerfile`](./Containerfile) selects the pinned Bazzite base and runs the customization script.
- [`build_files/build.sh`](./build_files/build.sh) installs and removes software during the image build.
- [`build_files/rpms`](./build_files/rpms) contains the licensed Epson vendor RPMs used by the image.
- [`system_files`](./system_files) contains files copied directly into the image filesystem.
- [`.github/workflows/build.yml`](./.github/workflows/build.yml) builds, signs, and publishes the OCI image.
- [`.github/workflows/build-disk.yml`](./.github/workflows/build-disk.yml) can create installation media manually.

## Local build

The normal build is performed by GitHub Actions. For local testing, install Podman and `just`, then run:

```bash
just build improved-distro latest
```

The image is based on Universal Blue's official [image-template](https://github.com/ublue-os/image-template). See the [Bazzite custom image documentation](https://docs.bazzite.gg/Advanced/creating_custom_image/) for background and supported approaches.

## Disclaimer

This is a personal image, not an official Bazzite or Universal Blue release. Bazzite, Universal Blue, Fedora, Epson, Brave, Microsoft, Discord, and the other included projects remain the property of their respective owners.
