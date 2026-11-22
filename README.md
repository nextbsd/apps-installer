# Installer

Installer puts NextBSD onto a disk. NextBSD works like an appliance, so
Installer asks as little as possible. Installer is part of NextBSD and
installed by pkg. It installs NextBSD itself; apps come from Software.

It's at the design stage, planned in
[nextbsd/nextbsd#662](https://github.com/nextbsd/nextbsd/issues/662) (epic
E46).

## Keep it simple

1. **Welcome:** Install.
2. **Choose a disk:** everything on the selected disk will be erased.
   Next.
3. **Installing:** one progress bar.
4. **Installed:** Restart.

No language, network, time zone, keyboard or account screens, no disk
layout choices, and no technical detail on screen.

## From the install image, or from an installed system

- **From the install image** (the ISO or USB stick), Installer installs
  NextBSD on the computer. The installer's own disk can't be chosen.
- **From an installed NextBSD**, Installer installs a copy of the running
  system, with its accounts, apps and settings, on another disk. The current
  system's disk can't be chosen; with no other disk connected, it asks you to
  connect one. Moving to a new disk works this way.

## Mockup

[`mockups/installer.html`](mockups/installer.html) is an interactive
simulator of Installer in the NextBSD theme. Download it and open it in a
browser. The Simulator controls panel (bottom left) switches between running
from the install image and from an installed system, starts from any step,
forces a failure (no usable disk, a write error) and speeds time up. Disks
and timings are sample data.

## License

BSD 2-Clause. See [LICENSE](LICENSE).
