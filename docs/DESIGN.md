# Reef Drift for Omarchy: design

Design notes (written before the build; the README describes what shipped).

## Goal

A standalone Omarchy shell plugin that plays Reef Drift as a full-screen overlay, written in QML.
It is a fork of the original HTML5 game (the web game). The web repo is not modified and the two share no code
at runtime. The plugin keeps the game's character: one Napoleon wrasse grows from 3 to 26 px radius by eating
smaller fish, soft stakes ("scattered", never game over), six-minute day/night, no score, quiet piano and ocean wash.

Success means: a player launched from a keybind sees and hears the same game as the web version, and the plugin
passes the same kind of checks the existing plugins does (logic tests, headless smoke, `omarchy plugin validate`).

## Decisions already made

- Rendering: **pre-baked PNG sprites composited with QML `Image` items** (not QML Canvas, not scene-graph shapes).
  This drops the web version's "no asset files" rule for the plugin only.
- Audio: **rendered to files at build time**, and they must sound the same as the web version.
- Layout and conventions follow another Omarchy plugin. Public identity is Cob Muddybug (repo-local git config set).

## Repository layout

```
the original HTML5 game-plugin/
  manifest.json          id io.github.cobmuddybug.reefdrift, kinds bar-widget + overlay
  BarWidget.qml          click to play (same pattern as the existing plugins). The icon is a plain monochrome fish glyph
                         that takes the bar's normal icon/text colour (no custom colouring, no game palette).
  Overlay.qml            PanelWindow, 16:9 card, IpcHandler, pause on close
  engine/                Input.qml, Store.qml, Sfx.qml, Music.qml, Palette.qml
  logic/                 ported verbatim from the web src: sim, behaviour, spawner, species,
                         world, rng, save, music (mood/track choice), scenes. Plain JS, no DOM.
  ui/                    App.qml, GameView.qml, Sprite lookup (sprites.js), HUD/title/pause screens
  sprites/               atlas PNGs + atlas.json (generated, committed)
  sounds/                sfx/*.ogg, loops/*.ogg, music/*.ogg (generated, committed)
  dev/                   tests, tools (bake-sprites, bake-audio), headless QML harness, run.sh, smoke.sh
  docs/                  this spec, plan, CREDITS (music)
  Makefile               install validate enable restart dev test bake smoke check
```

`make install` rsyncs the runtime files only (excludes `dev`, `docs`, `Makefile`), like the existing plugins.

## Logic port

`sim.js`, `behaviour.js`, `spawner.js`, `species.js`, `world.js`, `rng.js`, `save.js`, `music.js` (selection only),
`scenes.js` (state flow) are copied into `logic/` and adapted to load in QML (`.pragma library`, no ES module
syntax, no `document`/`window`). Existing tests move to `dev/tests` and keep running under Node through a small
loader, as the existing plugins does. The bot (`bot.js`) is ported for headless verification. Randomness uses the existing
seeded rng. Behaviour must match the web sim: the ported sim tests are the proof.

## Sprite bake

The sprite grids are procedural (`fishLength = r*3.1`, per-species shapes, frames, facing). `dev/tools/bake-sprites.js`
imports the web repo's `sprites.js` and `palette.js` (path via env var, default `../reef-drift`) and:

1. Enumerates every (species, length, frame, facing) the sim can request, from `SPECIES` radius ranges, plus the
   player at every length from `START_R` to `MAX_R`, plus coral/anemone kinds, variants and sizes.
2. Renders each grid to RGBA, packs them into a small number of atlas PNGs (power-of-two sheets), and writes
   `atlas.json`: key -> {sheet, x, y, w, h, anchor/eye offsets}.
3. Bakes the world layers (water ramp, light shafts, far and mid ridges, seabed) for each of the 4 night steps,
   and the pixel-font glyph strip.

Runtime `ui/sprites.js` quantises a requested radius to the nearest baked length. A bake test asserts that every
request the sim can make resolves to an entry. Colours are fixed at bake time; there is no Omarchy-theme tinting.

## Scene

- A logical 320x180 `Item` scaled by an integer factor to fit the 16:9 card, `smooth: false` everywhere.
- A frame-synced timer steps the logic with the web version's fixed timestep and feeds the camera.
- Creatures: a `Repeater` over the visible set (world-wrapped), each an `Image` with `sourceClipRect` into the atlas.
- Background: tiled `Image` layers with the web parallax factors; the night step is crossfaded between baked
  layers by opacity. Darkness overlay, plankton glow, bubbles, ripples and the HUD are small QML items.
- Screens: title, play, pause, as in the web version's `scenes.js`. HUD stays minimal (no score).

## Input

Arrows/WASD swim, Space or right-click flick, Esc pause (also saves), M mute, hold mouse to swim toward the pointer
(gentle when near). Key handling follows the existing plugins' `Input.qml`. The pointer vector reuses the ported
`pointerVector` maths. Held keys are cleared when the overlay closes.

## Audio

Goal is the same sound as the web version, so the bake **runs the web repo's actual `audio.js` synthesis**
rather than re-implementing it:

- `dev/tools/bake-audio.js` drives headless Chromium (`/usr/bin/chromium`) with an `OfflineAudioContext`
  standing in for `AudioContext`, calls each `SFX` entry and each music track, and writes WAV, then encodes to OGG.
- **SFX:** eat (a few pitches covering the radius range, selected by `eatPitch(r)` at runtime), flick, scatter,
  respawn, warn, dizzy, whale, fullgrown, chime variants, menu, confirm.
- **Music:** each of the 8 public-domain pieces rendered once with the web voice (pad/bell, echo bus, `SPEED = 0.92`),
  played by QML `MediaPlayer`/`AudioOutput` with the web version's mood rules (`moodOf`, `pickTrack`, hysteresis,
  long silences, fades).
- **Ambience:** the ocean wash is a seamless loop; the web version's depth/night filter movement is approximated by
  a few baked loop layers (surface, deep, night) crossfaded by volume.
- **Check:** a comparison script renders the same cues from the web build and the baked files and compares
  loudness and spectra within tolerance; I also listen-check by feel where I can only measure. Known limit: chime
  timing in the web version is random, so chimes are baked as a pool of variants and chosen at runtime.

Music credits (Satie, Debussy, Schumann, Bach, Mendelssohn, public domain) are copied into `docs/CREDITS.md` and
`THIRD_PARTY.md`.

## Save

`engine/Store.qml` writes JSON to `~/.local/share/reefdrift/save.json` using the ported `save.js` shape
(`r, peak, time, mute`), saved on pause, close and a slow interval.

## Plugin surface

- Keybind SUPER+CTRL+ALT+R between `-- reefdrift: start/end` markers in `~/.config/hypr/bindings.lua` (only
  added with your OK at install time).
- IPC target `io.github.cobmuddybug.reefdrift`: `open close toggle tap hold release state shot` for scripting
  and tests (`state` returns screen, r, depth, time, nearest creature).

## Testing

1. `make test`: ported Node logic tests (sim, behaviour, spawner soak, species, world, save, rng, input, music logic).
2. Bake test: sprite requests all resolve; atlas bounds valid; audio files exist and are non-silent.
3. `make smoke`: headless QML harness boots the overlay with a temp `REEFDRIFT_HOME`, runs the bot via IPC,
   takes screenshots (title, swim, night, pause), and asserts that `state` matches the logic sim.
4. `omarchy plugin validate`.
5. Visual parity: screenshots of the same seeds from the web build and the plugin, compared by eye.

## Risks

- Atlas size and sprite count: estimated ~1,500 sprites; if larger than expected, lengths are quantised more coarsely.
- Offline rendering of the web audio graph may need small shims for the timer-driven scheduling in `audio.js`.
- Rendering the web audio in headless Chromium needs the web repo present at bake time (generated files are committed,
  so the plugin repo is buildable and installable without it).
- QML `Repeater` with a few dozen moving items at 60 fps should be fine; if not, fall back to a pooled model.

## Out of scope

Theme tinting, new gameplay, species changes, a score or game over, web build of the plugin, pushing to GitHub.
