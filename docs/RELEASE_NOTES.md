Ripperdoc @VERSION@ installs the Cyberpunk 2077 mod frameworks on the **native Mac version** of the game (Apple silicon,
Steam, game version **2.5.0**): RED4ext, redscript, TweakXL, ArchiveXL, Codeware, Cyber Engine Tweaks, Mod Settings,
Input Loader and Audioware. No developer tools needed.

> Unofficial. Not affiliated with CD PROJEKT RED or with the frameworks' authors. Back up your saves.

## Install

1. Download **Ripperdoc-@VERSION@.zip** below and double-click it. Move **Ripperdoc** to your Applications folder.
2. Open Ripperdoc. macOS says it can't verify the app, because Ripperdoc isn't notarized (that needs a paid Apple
   account). Click **Done**, then go to **System Settings > Privacy & Security**, scroll down, click **Open Anyway** next
   to Ripperdoc and confirm. This is needed only once.
3. On the **Status** page, click **Run** next to *Create the game copy*, then next to *Install all frameworks*.
4. Start Steam, then click **Play** in Ripperdoc.

Ripperdoc never changes your Steam install. It makes a copy of the game in `~/Games/Cyberpunk 2077 Ripperdoc` that
takes no extra disk space, and installs everything there. Steam's own Play button keeps starting the normal game.

**Mods:** drag a mod's download (zip, rar, 7z or folder, as made for Windows) onto the **Mods** page. Windows `.dll`
plugins don't work on a Mac. **Cyber Engine Tweaks overlay:** fn+F11.

## What's in this release

| File | What it is |
| --- | --- |
| `Ripperdoc-@VERSION@.zip` | the app; it downloads the frameworks itself and checks each one by sha256 |
| `modsettings-*.zip`, `cet-*.zip`, `audioware-*.zip` | prebuilt Mac builds of Mod Settings, Cyber Engine Tweaks and Audioware, which have no Mac release of their own yet. The app downloads them |
| `SHA256SUMS` | checksums of all of the above |

RED4ext (with TweakXL, ArchiveXL and Codeware), redscript and Input Loader are downloaded from their own projects'
releases.

## Sources and licenses

Ripperdoc itself is MIT. The prebuilt bundles are built from these exact sources, plus Ripperdoc's
[patches](https://github.com/@REPO@/tree/v@VERSION@/patches), with `ripperdoc build-bundle`:

- **Mod Settings** (MIT, by jackhumbert): macOS port by codeman101,
  [`ceb4354`](https://github.com/codeman101/mod_settings/commit/ceb435433536246ecab29c4de1123c2498ec4d5c), with
  Ripperdoc's registration fix
- **Cyber Engine Tweaks** (GPL-3.0 with a mod exception, by the CET team): macOS port by codeman101,
  [`b4a0e23`](https://github.com/codeman101/CyberEngineTweaks/commit/b4a0e23b3171e145d2f1dbe86f3115147180514c). The
  complete corresponding source is that commit plus the dependency versions pinned in
  [`components.json`](https://github.com/@REPO@/blob/v@VERSION@/components.json)
- **Audioware** (by Roms1383): macOS port by codeman101,
  [`0d9dad6`](https://github.com/codeman101/audioware/commit/0d9dad67c6d9d7f757f473b1b081060383ae2536). Its repository
  publishes no license. It's included here non-commercially, with credit, and will be removed at the author's request

Each plugin folder contains its project's license file.

## Known limits

- Steam version 2.5.0 only. After a game update, mods stay off until the frameworks support the new build (the app
  says so).
- Tested by the author on one Mac (M4, macOS 27). Mod Settings was checked in game; Cyber Engine Tweaks and Audioware
  load, but their overlay and sound were not tested by hand yet. See
  [STATUS.md](https://github.com/@REPO@/blob/v@VERSION@/docs/STATUS.md).
