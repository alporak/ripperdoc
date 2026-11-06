# Ripperdoc

One-click installer and launcher for Cyberpunk 2077 mod frameworks on **native macOS (Apple Silicon)**: RED4ext,
redscript, CET, ArchiveXL, TweakXL, Codeware and more. It uses the community Mac ports.

> **Unofficial. Not affiliated with CD PROJEKT RED** or with the authors of the frameworks it installs. Cyberpunk 2077
> is a trademark of CD PROJEKT S.A. Modding is at your own risk: back up your saves.

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
- Xcode command line tools (`xcode-select --install`)

## Use

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

Put mod files into the **clone** (`~/Games/Cyberpunk 2077 Ripperdoc`), in the same folders as on Windows:

| Mod files | Folder |
| --- | --- |
| `.archive`, `.archive.xl` | `archive/Mac/mod/` (Windows `.archive` files may need repacking for Mac) |
| `.yaml` / `.tweak` | `r6/tweaks/` |
| `.reds` | `r6/scripts/` (compiled on every `play`) |
| RED4ext plugins | `red4ext/plugins/<Name>/`. They need a **macOS `.dylib` build**; Windows `.dll` plugins do not work |

## Status

See [docs/STATUS.md](docs/STATUS.md) for what is verified on 2.5.0, and what is still missing.

## Credits

Ripperdoc is only the glue. The real work belongs to:

| Component | Project | License |
| --- | --- | --- |
| RED4ext (macOS) | [codeman101/RED4ext-macos](https://github.com/codeman101/RED4ext-macos), continuing [jackmaxwil/RED4ext-macos](https://github.com/jackmaxwil/RED4ext-macos), forked from [wopss/RED4ext](https://github.com/wopss/RED4ext) | MIT |
| TweakXL, ArchiveXL, Codeware | [psiberx](https://github.com/psiberx); Mac builds bundled in the RED4ext-macos release | MIT |
| redscript | [jac3km4/redscript](https://github.com/jac3km4/redscript) | MIT |

Ripperdoc itself: MIT, see [LICENSE](LICENSE).
