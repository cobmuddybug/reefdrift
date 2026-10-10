# Reef Drift

A small, quiet pixel-art game for the [Omarchy](https://omarchy.org) shell. You are a young Napoleon wrasse
drifting through a Great Barrier Reef. Eat what is smaller than you, slip into the coral when something bigger
comes by, and slowly grow. No score, no timers, no game over.

It opens as a full-screen overlay from a keybind or a bar icon, and closing it pauses and saves.

## Install

```sh
make install enable restart      # copies the plugin into ~/.config/omarchy/plugins and reloads the shell
```

Then add the bar icon from the Omarchy bar settings (a plain fish, in your bar's own colour), and/or bind a key.
In `~/.config/hypr/bindings.lua`, following the style of your other binds, point a key at:

```
omarchy-shell shell toggle io.github.cobmuddybug.reefdrift '{}'
```

`make uninstall` removes it.

## Play

| Input | Action |
|---|---|
| Arrows / WASD | swim |
| Hold mouse | swim toward the pointer (gentle when it is close) |
| Space / right-click | flick: a short burst, then a pause of about a second |
| Esc | pause (also saves); on the title screen, close |
| M | mute |

- Creatures **smaller than you** (under 85% of your size) are food. They shimmer now and then.
- Any fish **bigger than 120% of your size** can hurt you. One that is near carries a slow dark ring, and a ripple
  warns you before it chases. You can hide in coral and anemones big enough to fit you.
- If you are caught you are only **scattered**: a soft fade, a little lost growth, and you reappear in a shelter,
  safe for a few seconds. Nothing ever ends your game.
- Manta rays, turtles and whale sharks are gentle giants. Jellyfish just leave you dizzy for a moment.
- The sea has a six-minute day: dusk, night with glowing plankton, dawn.
- Quiet piano plays over the ocean wash: public-domain Satie, Debussy, Schumann, Bach and Mendelssohn, chosen by
  where you are, with long silences between pieces. See [docs/CREDITS.md](docs/CREDITS.md).
- Your size, best size, time of day and mute are saved in `~/.local/share/reefdrift/save.json`.

## Scripting

```sh
omarchy-shell io.github.cobmuddybug.reefdrift open | close | toggle | state | tap Space | hold Right | release Right | go title | shot /tmp/x.png
```

Key names are Qt's (`Space`, `Right`, `Escape`, `M`). `state` prints the screen, size, depth, time of day, what is playing and more, as JSON.

## How it is built

Reef Drift started as a plain HTML5 canvas game. This plugin runs the same simulation in QML:

- `logic/reef.js` is that game's pure logic (sim, behaviour, spawner, species, world, rng, fx, save, music
  selection), bundled mechanically by `dev/tools/bundle-logic.mjs`. Its tests are ported the same way.
- `sprites/` and `ui/atlas.js` are the pixel art, baked to PNG by `dev/tools/bake-sprites.mjs` (a sprite atlas, the
  four night-time versions of each sea layer, the bitmap font). `ui/GameView.qml` composites them as images, with
  one small canvas for the one-pixel effects.
- `sounds/` is rendered by running the original WebAudio synthesiser offline in headless Chromium
  (`dev/tools/bake-audio.mjs`): effects as WAV, the music and the ocean wash as Ogg Vorbis.
- `ui/App.qml` is the title, swim and pause screens and the frame loop; `engine/` is input, save and sound.

The baked files are committed, so installing needs no build. To rebuild them you need the original game's source
(`REEF_WEB=/path/to/it make bake`), Chromium and ffmpeg.

```sh
make test      # logic tests, bake coverage tests, camera/menu tests
make smoke     # boots every screen in a headless QML harness and checks state and QML errors
make dev       # play in a normal window outside the shell
make check     # tests + smoke + omarchy plugin validate
```

## Licence

MIT, see [LICENSE](LICENSE). The music is public domain, see [docs/CREDITS.md](docs/CREDITS.md) and
[THIRD_PARTY.md](THIRD_PARTY.md).
