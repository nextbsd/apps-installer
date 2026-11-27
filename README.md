# Installer

Installer puts NextBSD onto a disk. NextBSD works like an appliance, so
Installer asks as little as possible. Installer is part of NextBSD and
installed by pkg. It installs NextBSD itself; apps come from Software.

It's planned in
[nextbsd/nextbsd#662](https://github.com/nextbsd/nextbsd/issues/662) (epic
E46) and built in
[nextbsd/nextbsd#670](https://github.com/nextbsd/nextbsd/issues/670).

## Keep it simple

1. **Welcome:** Install.
2. **Choose a disk:** everything on the selected disk will be erased.
   Next.
3. **Installing:** one progress bar.
4. **Installed:** Restart, Shut Down.

No language, network, time zone, keyboard or account screens, no disk
layout choices, and no technical detail on screen.

## From the install image, or from an installed system

- **From the install image** (the ISO or USB stick), Installer installs
  NextBSD on the computer. The installer's own disk can't be chosen.
- **From an installed NextBSD**, Installer installs a copy of the running
  system, with its accounts, apps and settings, on another disk. The current
  system's disk can't be chosen; with no other disk connected, it asks you to
  connect one. Moving to a new disk works this way.

## How it installs

Installer doesn't partition or copy anything itself. The install is the text
installer's engine in nextbsd-userland (`src/nextbsd-installer/engine`,
installed in `/usr/libexec/nextbsd-installer`), the same scripts
`nextbsd-installer` runs:

- **`probe-disks.sh`** lists the disks, says which one the running system
  started from, whether this is the install image or an installed system, and
  the smallest usable disk (30,000,000,000 bytes, what a "32 GB" stick holds;
  a copy needs room for the system's files too). Installer runs it as the user
  every few seconds while the disks show, so the list follows disks as they
  come and go.
- **`do-install.sh`** erases the disk and installs: GPT with a BIOS boot
  partition (amd64), an EFI system partition and a UFS root. From the install
  image it copies the image's system; from an installed NextBSD
  (`do-install.sh -c`) it copies the running system from a UFS snapshot,
  without temporary files, swap or per-boot state, keeping the accounts, apps
  and settings, and gives the copy its own root label, SSH host keys and
  random seed.

Erasing a disk needs root, so the settings apps' privileged helper,
`org.nextbsd.SettingsHelper`, runs the engine: `InstallStart` (right
`org.nextbsd.installer`, an administrator, asked every time),
`InstallProgress` and `InstallRestart`. The helper checks the disk with
`probe-disks.sh` again itself before it erases anything: never the disk the
system runs from, never one too small. Installer asks through
`Frameworks/NBSettings`, a copy of apps-settings' with Installer's three calls
added, and shows its authorization panel ("Allow changes?" for an
administrator without a password, as the install image's `admin` is).

## Building

```sh
. /System/Library/Makefiles/GNUstep.sh
gmake ADDITIONAL_LIB_DIRS="-L/Developer/Link -L/usr/X11/lib"
gmake install            # ~/Applications/Installer.app
```

It needs the engine and the helper from nextbsd-userland with Installer's
operations.

## Trying it without a disk

Installer lists memory disks only in the probe's test mode, which only root
can turn on and which ends at the next restart:

```sh
truncate -s 40g /tmp/test-disk.img
mdconfig -a -t vnode -f /tmp/test-disk.img        # prints md0, say
touch /var/run/nextbsd-installer.test-disks
```

The disk shows as "Test disk (md0)", and Installer installs on it like on any
other. Restart after an install on a test disk restarts nothing. Afterwards,
`mdconfig -d -u 0` and move `/var/run/nextbsd-installer.test-disks` away.

## Mockup

[`mockups/installer.html`](mockups/installer.html) is an interactive
simulator of Installer in the NextBSD theme. Download it and open it in a
browser. The Simulator controls panel (bottom left) switches between running
from the install image and from an installed system, starts from any step,
forces a failure (no usable disk, a write error) and speeds time up. Disks
and timings are sample data.

## License

BSD 2-Clause. See [LICENSE](LICENSE).
