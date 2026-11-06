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
| Input Loader | | risner/cyberpunk2077-input-loader-mac | not yet | |
| Mod Settings | | jackhumbert/mod_settings PR #32 | not yet | |
| Cyber Engine Tweaks | | maximegmd/CyberEngineTweaks PR #1068 | not yet | GPL-3.0: Ripperdoc will build/download it, never bundle it |
| Audioware | | cyb3rpsych0s1s/audioware PR #103 | not yet | the repo has no license, so it is local builds only |

"Loads" means the plugin started without errors. "Works" means its job was checked end to end.
