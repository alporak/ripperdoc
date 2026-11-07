# Ripperdoc

[![Buy me a coffee](https://img.shields.io/badge/Buy%20me%20a%20coffee-alporak-FFDD00?logo=buymeacoffee&logoColor=black)](https://buymeacoffee.com/alporak)

One-click installer and launcher for Cyberpunk 2077 mod frameworks on **native macOS (Apple Silicon)**: RED4ext,
redscript, CET, ArchiveXL, TweakXL, Codeware and more. It uses the community Mac ports.

> **Unofficial. Not affiliated with CD PROJEKT RED** or with the authors of the frameworks it installs. Cyberpunk 2077
> is a trademark of CD PROJEKT S.A. Modding is at your own risk: back up your saves.

## Download (no developer tools needed)

1. Get **Ripperdoc-x.y.z.zip** from the [latest release](https://github.com/alporak/ripperdoc/releases/latest), open it,
   and move **Ripperdoc** to Applications.
2. The first time you open it, macOS says it can't verify the app: Ripperdoc isn't notarized, because that needs a
   paid Apple account. Click **Done**, then **System Settings > Privacy & Security > Open Anyway**. This is needed only once.
3. On the **Status** page, run *Create the game copy*, then *Install all frameworks*.
4. Start Steam, then press **Play** in Ripperdoc.

> The release is unsigned because I don't have an Apple Developer account. Feel free to
> [donate](https://buymeacoffee.com/alporak) if you'd like a signed release!

## How it works

- **Your Steam install is never modified.** Ripperdoc clones the game into `~/Games/Cyberpunk 2077 Ripperdoc` with an
  APFS clone. The clone shares disk blocks with the original, so it takes no extra space until files change. Only the
  clone's binary is re-signed so it can load mod frameworks. Steam's **Play** button keeps starting the untouched game.
- **Every framework comes from its own project,** pinned to an exact release in [`components.json`](components.json)
  and checked by sha256 before install. Ripperdoc does not rehost or rebrand anyone's work.
- Saves, achievements and cloud saves work as normal; Steam has to be running.

## Requirements

- Cyberpunk 2077 **2.5.0** (Steam) on an Apple silicon Mac, macOS 15.5 or later
- The game folder and your home folder on the same APFS volume (the default)
- Only for building from source (`--from-source`, or the app from the repo): Xcode command line tools, and
  `brew install cmake ninja fmt spdlog freetype libpng rustup`, then `rustup default stable`

## Use

### The app, from source

```bash
git clone https://github.com/alporak/ripperdoc.git && cd ripperdoc
app/build-app.sh                     # builds app/build/Ripperdoc.app (no Xcode project needed)
open app/build/Ripperdoc.app
```

**Status** walks you through setup (create the game copy, install the frameworks) and shows every health check.
**Frameworks** lists each component with its version, license and upstream project. **Mods** takes mods by drag and drop.
**Play** starts the modded game; its output goes to **Log**. The app carries the CLI below and runs it for every
action, so both always behave the same.

The app is ad-hoc signed. On another Mac, the first launch needs right-click > **Open**. To work on it in Xcode, open the
`app/` folder (it is a Swift package).

### The command line

`install` downloads prebuilt Mod Settings, CET and Audioware bundles from the release; `install --from-source` builds
them locally instead (needs the Homebrew packages above). Maintainers: `scripts/release.sh build|publish <version>`.

```bash
git clone https://github.com/alporak/ripperdoc.git && cd ripperdoc
./ripperdoc setup      # clone the game (instant, no extra disk space)
./ripperdoc install    # download, verify and install the frameworks
./ripperdoc doctor     # check everything
./ripperdoc play       # start the modded copy (Steam must be running)
```

After a Steam update, run `./ripperdoc refresh`. It re-clones the game and keeps your mods. Mods stay off until the
pinned frameworks support the new build.

To remove everything: `./ripperdoc uninstall --yes` deletes the clone. Your Steam install was never changed.

## Installing mods

```bash
./ripperdoc mod add ~/Downloads/SomeMod.zip   # .zip, .rar, .7z or a folder, as downloaded for Windows
./ripperdoc mod list
./ripperdoc mod remove SomeMod
```

`mod add` maps the Windows folders to the Mac ones below, refuses to overwrite files it does not own, skips what cannot
work on a Mac (Windows `.dll` plugins, REDmod) and records every file, so `mod remove` takes out exactly those.

By hand, files go into the **clone** (`~/Games/Cyberpunk 2077 Ripperdoc`), in these folders:

| Mod files | Folder |
| --- | --- |
| `.archive`, `.archive.xl` | `archive/Mac/mod/` (Windows `.archive` files may need repacking for Mac) |
| `.yaml` / `.tweak` | `r6/tweaks/` |
| `.reds` | `r6/scripts/` (compiled on every `play`) |
| RED4ext plugins | `red4ext/plugins/<Name>/`. They need a **macOS `.dylib` build**; Windows `.dll` plugins do not work |
| CET Lua mods (`bin/x64/plugins/cyber_engine_tweaks/mods/<Name>` on Windows) | `red4ext/plugins/cyber_engine_tweaks/mods/<Name>/` |
| Key bindings (`r6/input/*.xml`) | `r6/input/` (merged on every `play`) |
| Audioware mods | `r6/audioware/<Name>/` |

**CET overlay key:** F11. macOS uses F11 for Show Desktop, so either turn that off (System Settings > Keyboard >
Keyboard Shortcuts > Mission Control) or press fn+F11, or change the key in CET's Bindings tab.

## Graphics

The app's **Graphics** page (or `./ripperdoc graphics`) switches between your own settings and **Clarity**, a profile
measured to give a noticeably sharper image at a steady 30 fps on a base M4, and runs the game's benchmark to measure
any change. See [docs/GRAPHICS.md](docs/GRAPHICS.md) for the numbers.

## Status

See [docs/STATUS.md](docs/STATUS.md) for what is verified on 2.5.0, and what is still missing.

## Patches Ripperdoc carries

Each patch fixes an upstream port for the public macOS loader. It is applied to the pinned commit at install time,
and it goes away once the fix is merged upstream.

| Patch | Fixes |
| --- | --- |
| [`patches/modsettings/0001`](patches/modsettings/0001-register-natives-from-the-rtti-post-register-callback.patch) | Mod Settings waited for a Frida-based loader to call `modsettings_registerNatives`; with the public loader its natives never registered and the game stopped at script load. It now registers from the RTTI post-register callback, after Codeware |

Ripperdoc also works around two install issues without patching anyone's code: it installs `ModSettings.archive.xl`
(without it, the menu entry has no label), and it gives Input Loader the game's 2.5 input file under the 2.3 name the
script reads, instead of the stale 2.31 configs in its repository.

## Support

A lot of work went into making these frameworks run on the Mac. If Ripperdoc saved you time, I'd appreciate it if you
[buy me a coffee](https://buymeacoffee.com/alporak). It also helps toward a signed, notarized release.

## Credits

Ripperdoc is only the glue. The real work belongs to:

| Component | Project | License |
| --- | --- | --- |
| RED4ext (macOS) | [codeman101/RED4ext-macos](https://github.com/codeman101/RED4ext-macos), continuing [jackmaxwil/RED4ext-macos](https://github.com/jackmaxwil/RED4ext-macos), forked from [wopss/RED4ext](https://github.com/wopss/RED4ext) | MIT |
| TweakXL, ArchiveXL, Codeware | [psiberx](https://github.com/psiberx); Mac builds bundled in the RED4ext-macos release | MIT |
| redscript | [jac3km4/redscript](https://github.com/jac3km4/redscript) | MIT |
| Input Loader (macOS) | [risner/cyberpunk2077-input-loader-mac](https://github.com/risner/cyberpunk2077-input-loader-mac), a rewrite of [jackhumbert/cyberpunk2077-input-loader](https://github.com/jackhumbert/cyberpunk2077-input-loader) | BSD-2-Clause |
| Mod Settings (macOS) | [codeman101/mod_settings](https://github.com/codeman101/mod_settings) ([PR #32](https://github.com/jackhumbert/mod_settings/pull/32)), by [jackhumbert](https://github.com/jackhumbert/mod_settings) | MIT |
| Cyber Engine Tweaks (macOS) | [codeman101/CyberEngineTweaks](https://github.com/codeman101/CyberEngineTweaks) ([PR #1068](https://github.com/maximegmd/CyberEngineTweaks/pull/1068)), by the [CET team](https://github.com/maximegmd/CyberEngineTweaks). The release's prebuilt bundle is built from that exact commit and the pinned dependencies in `components.json` | GPL-3.0 + mod exception |
| Audioware (macOS) | [codeman101/audioware](https://github.com/codeman101/audioware) ([PR #103](https://github.com/cyb3rpsych0s1s/audioware/pull/103)), by [Roms1383](https://github.com/cyb3rpsych0s1s/audioware). Its repository publishes no license; it is included non-commercially, with credit, and will be removed at the author's request | none published |

Ripperdoc itself: MIT, see [LICENSE](LICENSE).
