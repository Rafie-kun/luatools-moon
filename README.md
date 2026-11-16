# 🌕 luatools-moon

## Install

Set up slsteam-moon, Lumen and the LuaTools plugin automatically with a single command:

```bash
curl -fsSL https://raw.githubusercontent.com/swwayps/luatools-moon/main/install.sh | bash
```

> **Requirements:** Linux x86_64 and **native Steam** installed from your package
> manager. Flatpak and Snap Steam are not supported.
>
> **Already using Millennium?** You can keep it. Lumen needs Steam's CEF
> debug port, which Millennium keeps shut, so the installer drops
> `~/.steam/steam/.cef-enable-remote-debugging` to open it — Millennium's
> loader and settings stay where they are. If you'd rather drop just the
> loader, `--keep-millennium` removes it and keeps your settings and themes;
> `--remove-millennium` takes everything.

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

Open an issue: https://github.com/swwayps/luatools-moon/issues

## Uninstall

Want to remove everything? Run:

```bash
curl -fsSL https://raw.githubusercontent.com/swwayps/luatools-moon/main/uninstall.sh | bash
```
