# Borrowed Luck: CLAUDE.md

Gambling roguelike for a game jam (theme TRICK). Godot 4.7, GDScript, 2D, GL Compatibility renderer,
PC and phone. This file is the map of the project: read it before claiming how anything works.
Design decisions and numbers: `docs/GAME_DESIGN.md`. Asset register: `assets/README.md`.

## 0. Critical rules

1. **Everything lands on `main`, no side branches, commits are the author's** (the author's rule).
2. **No comments in `project.godot`.** Godot rewrites the file and folds `#` into a key name, silently
   killing the setting. (The `;` header Godot writes itself is fine.)
3. `node.get("field")` returns `null` for a missing field, and `bool(null)` crashes. Write
   `v.get("field") == true`.
4. **Never guard a freed reference with `!= null`: use `is_instance_valid(x)` and nothing else.** A freed
   object is not nil, and handing it to a typed parameter or a typed local is a runtime error.
5. A field named like a native class member ("Member X redefined") stops the script from loading.
   Signals count. Do not name locals `name`, `position` etc. either (shadowing warning).
6. A single-line lambda ends at the newline. Anything longer is a named method with `.bind()`.
7. **Never set position or size on a container child.** The container overwrites it. Cards live in
   `HandView`, a plain `Control` that lays them out by hand.
8. **A new `class_name` is not named from another file: preload it** (`const X := preload("res://...")`).
   A file that arrives by `git pull` can land before the editor's class cache knows it. This project
   declares no `class_name` at all; everything is reached through `preload`.
9. Every gate goes at the **single door**. A rule is changed in the table or in an artifact hook, never
   patched from a scene.
10. UI strings are translation **keys** (`TABLE_DEAL`), never literals. Controls translate `text` on
    their own; strings built in code go through `tr()`. Add both `en` and `ru` to `i18n/strings.json`.
11. Pixel art is shown with Nearest filtering (project default). Icons that are SVG are shown with
    `LINEAR_WITH_MIPMAPS`.

## 1. Project skeleton

```
autoload/   Events (signal bus), Loc (translations), Catalog (artifacts), Profile (meta + save),
            Audio (sfx and music), Game (current run and screen changes)
core/       pure logic, no nodes: Rules (all numbers), Stat (counter names), Card, Shoe, RunState, Dealer
data/       ArtifactData (resource), ArtifactEffect (behaviour base), catalog.tres,
            artifacts/<game>/*.tres and artifacts/<game>/effects/*.gd
games/<game>/  one folder per casino game: table (rules) + scene (view)
ui/         menu, lobby, result, common components (CardView, HandView, ArtifactSlot, ArtifactTile),
            theme.tres (built by tools/build_theme.gd)
i18n/       strings.json  {KEY: {en, ru}}
assets/     art, ui, audio, fonts, shaders (see assets/README.md)
tools/      generators: generate_sfx.py, generate_cards.py, build_theme.gd
docs/       design and per-system notes
```

Screen flow: `main_menu` -> `lobby` (pick 3 artifacts) -> table scene -> `result` -> lobby or menu.
Base resolution is 640x360 with `canvas_items` stretch and `expand` aspect: pixel art is drawn at 1:1
and scaled by an integer on any screen.

## 2. Architecture invariants

### Logic never touches nodes, the view never decides rules

- `games/blackjack/blackjack_table.gd` is a `RefCounted`. It owns the shoe, both hands, the bet, the
  phase, and **every rule decision**. It talks to the screen through its own signals.
- `blackjack_scene.gd` turns each signal into a **queued animation step** (`_enqueue`, `_pump`). The rules
  resolve instantly; the screen lags a beat behind so nothing is spoiled (a payout never shows before the
  dealer's last card lands). Input is ignored while the queue runs. Every UI change goes through the queue,
  including labels, or they would run ahead of the cards.
- A new game is a new `games/<name>/` folder with the same shape, a row in `Game.TABLES`, its own artifacts
  in `data/artifacts/<name>/`, and a way to pick it in the lobby.

### Artifacts are data plus a hook script

- `ArtifactData` (a `.tres`) says what it is: kind, rarity, icon, charges, unlock rule. Texts are keys built
  from the id: `ARTIFACT_<ID>_NAME / _DESC / _HINT`.
- `effect_script` extends `ArtifactEffect` and overrides only the hooks it needs: `hand_started`,
  `can_use` / `use` (buttons), `prevent_bust`, `modify_payout`, `modify_payment`, `modify_min_bet`,
  `prevent_death`. The table and `RunState` call them at fixed points. **Never patch a rule from outside.**
- A new artifact: write its effect script, its `.tres`, add it to `data/catalog.tres`, add three
  translation keys. Nothing else changes.
- `payout` is the chips returned for the bet (0 on a loss). A curse may return less than 0; the purse
  clamps at 0.

### Meta progress: counters and unlocks

- Gameplay code announces facts through `Events.stat_added` / `Events.stat_peaked` with a name from
  `core/stat.gd`. `Profile` keeps the counters, saves `user://profile.json`, and unlocks an artifact the
  moment `stat(unlock_stat) >= unlock_value`. Fresh unlocks wait in `Profile.fresh_unlocks` for the result
  screen. An artifact with an empty `unlock_stat` is open from the start.
- Adding an unlock rule is data only. Adding a new counter is one constant in `Stat` and one emit.

### The run

- `RunState` owns chips, the payment clock and the equipped effects. A payment is due every
  `Rules.PAYMENT_EVERY` hands and each one is bigger. Failing to pay, or running out of chips, kills the
  run unless an effect's `prevent_death` saves it. Death does not touch the meta progress.

## 3. Running it

The engine is not installed in a fresh container and cannot be downloaded (the proxy blocks
godotengine.org and release downloads), but `git clone` of GitHub works, so it is built from source once
(about 20 minutes on four cores):

```sh
apt-get install -y --no-install-recommends scons pkg-config build-essential libx11-dev libxcursor-dev \
  libxinerama-dev libxi-dev libxrandr-dev libxext-dev libxrender-dev libgl1-mesa-dev libglu1-mesa-dev \
  libasound2-dev libpulse-dev libudev-dev libdbus-1-dev libspeechd-dev libwayland-dev \
  wayland-protocols libxkbcommon-dev xvfb
git clone --depth 1 -b 4.7.2-stable https://github.com/godotengine/godot.git /tmp/godot
cd /tmp/godot && scons platform=linuxbsd target=editor optimize=none debug_symbols=no lto=none \
  module_text_server_adv_enabled=no module_text_server_fb_enabled=yes module_raycast_enabled=no \
  module_lightmapper_rd_enabled=no module_openxr_enabled=no module_webxr_enabled=no \
  module_mobile_vr_enabled=no module_webrtc_enabled=no module_websocket_enabled=no \
  module_camera_enabled=no -j4
```

**Run on a copy, never on the repo.** Importing rewrites `.import` files and may reorder keys in
`project.godot`.

```sh
rm -rf /tmp/run && mkdir /tmp/run
tar -cf - --exclude=.git --exclude=.godot . | tar -xf - -C /tmp/run
G=/tmp/godot/bin/godot.linuxbsd.editor.x86_64
$G --headless --path /tmp/run --import
$G --headless --path /tmp/run --script res://tools/selftest.gd
```

`tools/selftest.gd` loads every script and scene and plays scripted blackjack hands against the real rules.
A shader or a drawn frame needs a real driver: `xvfb-run -a $G --path /tmp/run --rendering-driver opengl3`.
Headless never compiles a shader.

## 4. Working with the code

- After changing a hook signature, grep every effect script that overrides it.
- When behaviour changes, update this file and the matching page in `docs/` in the same commit.
- `tools/generate_sfx.py` and `tools/generate_cards.py` regenerate procedural assets; edit the script, not
  the output.

## 5. Style and conventions

- Comments and docs are in **English**. A comment is a working note: the rule, the number, the trap, why
  not otherwise. Never restate what the line does.
- Do not duplicate numbers that live in code: name the constant (`Rules`).
- Files are `snake_case`; no `class_name`; typed GDScript where it is cheap.
- Bold for hard prohibitions; no shouting.

## 6. Where to look next

- `docs/GAME_DESIGN.md`: decisions, the run loop, the artifact table.
- `assets/README.md`: every asset, its licence and its status.
