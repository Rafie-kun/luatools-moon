# 🌕 luatools-moon

## Install

Set up slsteam-moon, Lumen and the LuaTools plugin automatically with a single command.

This fork — same installer, plus the store button fix and the Workshop writer:

```bash
curl -fsSL https://raw.githubusercontent.com/Rafie-kun/luatools-moon/main/install.sh | bash
```

The original upstream line, if you'd rather have stock `swwayps` releases
(their plugin release is still v2.9, so the store button stays missing there):

```bash
curl -fsSL https://raw.githubusercontent.com/swwayps/luatools-moon/main/install.sh | bash
```

Both accept the same flags; swap the URL to pick which releases you get.

> **Requirements:** Linux x86_64 and **native Steam** installed from your package
> manager. Flatpak and Snap Steam are not supported.
>
> **Coming from Millennium?** Its loader has to go, because Millennium keeps
> Steam's debug port and Lumen needs that port to attach at all. The installer
> removes it; pass `--keep-millennium` if you want to keep your Millennium
> settings and themes folders for later.

Handy flags, passed after `-- `:

```bash
# keep Millennium settings, don't start Steam at the end
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
