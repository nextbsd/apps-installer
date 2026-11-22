# Installer

Installer puts NextBSD onto a computer's disk from the install image.
NextBSD works like an appliance, so Installer asks as little as possible and
sets up a complete, working desktop. Installer is part of NextBSD and
installed by pkg. It installs NextBSD itself; apps come from Software.

It's at the design stage, planned in
[nextbsd/nextbsd#662](https://github.com/nextbsd/nextbsd/issues/662) (epic
E46).

## Keep it simple

- **Few steps:** choose a language, choose a disk, confirm it will be erased,
  install, then set up what the first login needs: the time zone, the first
  administrator account, and Wi-Fi only when there's no wired connection.
- **No disk layout choices:** the whole disk is erased and used for NextBSD.
- **No technical detail on screen:** one progress bar while installing.
- **Then restart** into the installed system, which goes to the login window.

## License

BSD 2-Clause. See [LICENSE](LICENSE).
