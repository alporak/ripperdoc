# Status on Cyberpunk 2077 2.5.0 (Steam, build UUID 7D7382D0-EADD-36F0-BA1C-CEBEC1D5BEBC)

Tested on an M4 Mac, macOS 27.0.1.

| Component | Version | Source | State | Evidence |
| --- | --- | --- | --- | --- |
| RED4ext (macOS) | 0.3.0 | codeman101/RED4ext-macos release | **works** | 701 game addresses loaded, self-checks pass (RTTI, memory pool, CName pool, native function registration) |
| TweakXL | 1.11.4 | bundled in RED4ext-macos 0.3.0 | **loads** | TweakDB read (213,621 records); no test tweak yet |
| ArchiveXL | 1.27.4 | bundled in RED4ext-macos 0.3.0 | **loads** | initialises; log warns `No hooks attached by 'ArchiveXL' at 0x108f22fb8` (to investigate) |
| Codeware | 1.21.2 | bundled in RED4ext-macos 0.3.0 | **loads** | services start (`ButtonHintsManager`, `CustomPopupManager`) |
| redscript | 0.5.32 | jac3km4/redscript release | **works** | compiles game + plugin scripts before launch |
| Steam integration | | | **works** | stats and achievements received from Steam when started from the clone |
| Input Loader | 1.0 | risner/cyberpunk2077-input-loader-mac release | **merge works**; in-game redirect not yet confirmed | smoke binding merged and removed cleanly; with no mods the merged configs have identical bindings to 2.5's. Its 2.31 `r6/config` copies are not installed: 2.5 renamed `inputContexts_mac.xml` to `inputContexts.xml`, so Ripperdoc clones the 2.5 file under the old name for the script |
| Mod Settings | 0.2.21 (codeman101/mod_settings `ceb4354`, built from source) + Ripperdoc patch | jackhumbert/mod_settings PR #32 | **works** (menu entry and page checked in game) | Unpatched it made script loading fail (`R30 script loader returned 0`, then a SIGTRAP): the port waits for a Frida-based loader to call `modsettings_registerNatives`, which the public loader never does. `patches/modsettings/0001` registers it from the RTTI post-register callback, after Codeware, like TweakXL/ArchiveXL/Codeware do. Then: 7 types registered, both hooks attached, scripts load (`returned 1`). Its `.archive.xl` must sit next to the archive, or the menu entry has no label |
| Cyber Engine Tweaks | 1.38.0 (codeman101/CyberEngineTweaks `b4a0e23`, built from source) | maximegmd/CyberEngineTweaks PR #1068 | **works** (automated); overlay use not yet checked by hand | Lua VM starts, mods load (smoke mod: `init ok`, reads game state through `Game.*`), Metal overlay initialises, all game-state hooks install. Address rows checked against 2.5: 12 of 18 confirmed (verified RED4ext DB, other plugins' tables, vtable slots); the 6 log-native rows are plausible (single registration reference, real prologues). Known gap: `Could not get OodleLZ_Decompress`, so no TweakDB names in its tools. GPL-3.0: built locally, never bundled |
| Audioware | | cyb3rpsych0s1s/audioware PR #103 | not yet | the repo has no license, so it is local builds only |

"Loads" means the plugin started without errors. "Works" means its job was checked end to end.
