# Graphics: the Clarity profile

How the `clarity` profile ([profiles/clarity.conf](../profiles/clarity.conf)) was found, on a **base M4 MacBook Pro (16 GB)**
driving a 4K monitor, Cyberpunk 2077 2.5 with Phantom Liberty, at 1920×1080 output.

## Goal

A sharper image at a **steady 30 fps**. Sharpness first, then texture detail up close. A change was kept only if the
benchmark's slowest 1% of frames stayed at or above 30 fps **and** macOS did not start swapping. Swapping shows up as
stutter rather than a lower average.

## Method

`ripperdoc bench` runs the game's own benchmark (`-benchmark`; the game writes `summary.json` and `frames.csv` to
`~/Library/Application Support/CD Projekt Red/Cyberpunk 2077/benchmarkResults/` and quits by itself) with the frame cap off,
samples the game's memory footprint and the system's swap use every 5 s, and records average FPS, the 1%-low (from the
per-frame times) and the settings. Each step builds on the last one that was kept.

| Run | Change | Avg FPS | 1%-low | Footprint | Swap | Kept |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| 0 | before: MetalFX Balanced, Medium textures, 8× filtering, sharpness 0.5 | 63.5 | 40.4 | | | |
| 1 | anisotropic filtering 16× | 62.5 | 39.7 | 9.9 GB | +0 | yes |
| 2 | MetalFX sharpness 0.7 | 62.8 | 40.0 | 9.8 GB | +0 | yes |
| 3 | Texture Quality High (GPU memory 2.5 → 3.5 GB) | 62.7 | 39.0 | 9.8 GB | +0 | yes |
| 4 | MetalFX Quality (renders ~1440×810 instead of ~1270×720) | 56.3 | 37.8 | 9.9 GB | +0 | **yes** |
| 5 | output 2560×1440, MetalFX Quality | 37.2 | 26.7 | 10 GB | +0 | no: under 30 |
| 6 | output 2560×1440, MetalFX Balanced | 41.3 | 13.9 | 10 GB | +54 MB | no: swapping |
| 7 | LOD Medium (on run 4) | 54.4 | 29.9 | 10 GB | +366 MB | no: swapping |
| 8 | control: run 4 again | 56.7 | 38.4 | 9.9 GB | +0 | confirms run 4 |

**Result:** runs 1–4: about 57 fps average and a 38 fps 1%-low uncapped. The profile caps at 60, which played well;
for perfectly even pacing in heavy scenes, cap at 30 instead (`ripperdoc graphics set /video/display MaximumFPS_Value 30`).

## What didn't work, and why

- **Higher output resolution** (1440p) costs memory as well as GPU time (output-sized buffers and post-processing). On
  16 GB it starts swapping, which is the stutter in run 6.
- **LOD Medium** loads more detailed geometry and starts swapping too (run 7). Run 8 rules out leftover memory pressure
  from runs 5 and 6.
- **Mip bias / texture streaming engine settings** can't be changed on the Mac yet: the Mac port of Cyber Engine Tweaks
  has no access to the engine's config system (`GameOptions.Dump()` returns 0 options), and their config sections aren't
  plain strings in the Mac binary.
- **Frame generation** wasn't measured for this profile, which already runs close to its 60 cap.
- **HD texture packs:** not tried. Whether loose archives can replace base-game textures on the Mac is disputed, and
  memory is already the limit.

## Use

```bash
./ripperdoc graphics apply clarity   # or the app's Graphics page
./ripperdoc graphics reset           # back to exactly what you had before
./ripperdoc bench mytest             # measure your own changes (game closed, hands off for ~3 minutes)
./ripperdoc bench list
```

These are the game's own settings (`UserSettings.json`), so they apply to the Steam game too. Other Macs need their own
measurements: run `ripperdoc bench` before and after.
