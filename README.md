# 🌕 luatools-moon

## Install

Set up slsteam-moon, Lumen and the LuaTools plugin automatically with a single command.

This fork — same installer, plus the store button fix, the Workshop writer, and
the 64-bit (`steamrt64`) port from
[ogb4n/slsteam-moon-x64](https://github.com/ogb4n/slsteam-moon-x64) (installed
from this fork's builds when that repo has no reachable release) instead of
upstream's 32-bit v2.9:

```bash
curl -fsSL https://raw.githubusercontent.com/Rafie-kun/luatools-moon/main/install.sh | bash
```

The original upstream line, if you'd rather have stock `swwayps` releases
(their plugin release is still v2.9, and their slsteam-moon is 32-bit only, so
both the store button and the 64-bit build stay out):

```bash
curl -fsSL https://raw.githubusercontent.com/swwayps/luatools-moon/main/install.sh | bash
```

Both accept the same flags; swap the URL to pick which releases you get. The
64-bit build needs a `steamrt64` Steam client — if yours is still
`ubuntu12_32`, use the upstream line.

> **Requirements:** Linux x86_64 and **native Steam** installed from your package
> manager. Flatpak and Snap Steam are not supported.
>
> **Already using Millennium?** You can keep it. Lumen needs Steam's CEF
> debug port, which Millennium keeps shut, so the installer drops
> `~/.steam/steam/.cef-enable-remote-debugging` to open it — Millennium's
> loader and settings stay where they are. If you'd rather drop just the
> loader, `--keep-millennium` removes it and keeps your settings and themes;
> `--remove-millennium` takes everything.
>
> **Keeping up with Steam.** The slsteam-moon payload is checked against this
> fork's releases when Steam launches (at most once every six hours, sha256
> verified, old files kept under `~/.local/share/SLSsteam/backup/`). Export
> `SLSM_NO_AUTOUPDATE=1` to turn that off. Lumen runs as a systemd user service
> (`lumen.service`) so it is already up when Steam starts, whichever launcher
> you used — that used to take a few Steam restarts. `--no-lumen-service` goes
> back to wrapper-only; Lumen's log is at `~/.local/share/Lumen/lumen.log`.

Handy flags, passed after `-- `:

```bash
# drop the Millennium loader but keep its settings, and don't start Steam
curl -fsSL https://raw.githubusercontent.com/Rafie-kun/luatools-moon/main/install.sh | bash -s -- --keep-millennium --nolaunch

# slsteam-moon + Lumen only
curl -fsSL https://raw.githubusercontent.com/Rafie-kun/luatools-moon/main/install.sh | bash -s -- --noplugin
```

---

Linux port of the `ltsteamplugin` plugin, built exclusively for the [slsteam-moon](https://github.com/swwayps/slsteam-moon) project. It serves as an integration layer that fetches manifest packs and installs them for slsteam-moon to consume natively on Linux.

## Credits

Upstream:

- [piqseu](https://github.com/piqseu/ltsteamplugin) — the `ltsteamplugin`
  release line this fork tracks. Originally by
  [madoiscool](https://github.com/madoiscool/ltsteamplugin).

Reference material:

- [StarWarsK & geovanygrdt](https://github.com/Star123451/LuaToolsLinux) —
  prior Linux port.
- [Millennium](https://github.com/SteamClientHomebrew/Millennium) —
  Steam client modding framework.
- [CloudRedirect](https://github.com/Selectively11/CloudRedirect) by
  Selectively11 — optional cloud saves for unowned games.

## Support

Open an issue: https://github.com/Rafie-kun/luatools-moon/issues

## Uninstall

Want to remove everything? Run:

```bash
curl -fsSL https://raw.githubusercontent.com/Rafie-kun/luatools-moon/main/uninstall.sh | bash
```

Or with the upstream one, which is the same script:

```bash
curl -fsSL https://raw.githubusercontent.com/swwayps/luatools-moon/main/uninstall.sh | bash
```
