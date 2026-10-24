# Borrowed Luck: CLAUDE.md

Gambling roguelike for a game jam (theme TRICK). Godot 4.7, GDScript, GL Compatibility renderer, PC and
phone. The menus are 2D pixel UI; the table is a 3D room seen from the player's seat. This file is the map of the project: read it before claiming how anything works.
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
11. **Rye has no Cyrillic.** Text always uses `ui/fonts/title_font.tres` and
    `body_font.tres` (`FontVariation`: Rye first, Underdog as the
    fallback for Russian). Never reference the raw `.ttf` from a scene; a missing glyph silently falls
    back to a system font. Rebuilt by `tools/build_theme.gd`.
12. Pixel art is shown with Nearest filtering (project default). Icons that are SVG are shown with
    `LINEAR_WITH_MIPMAPS`.

## 1. Project skeleton

```
autoload/   Events (signal bus), Loc (translations), Catalog (artifacts), Profile (meta + save),
            Audio (sfx and music), Game (current run and screen changes)
core/       pure logic, no nodes: Rules (all numbers), Stat (counter names), Card, Shoe, RunState, Dealer
data/       ArtifactData (resource), ArtifactEffect (behaviour base), catalog.tres,
            artifacts/<game>/*.tres and artifacts/<game>/effects/*.gd
games/<game>/  one folder per casino game: table (rules) + 3D view + the dealer
world/      3D building blocks: casino_room.tscn (generated), CameraRig, CardActor, CardFaces, ChipStack,
            ChipPile, Plaque, ArtifactToken, FloatingText, Pickable base
ui/         menu, lobby, result, common components (CardView, ArtifactTile, vignette),
            theme.tres (built by tools/build_theme.gd)
i18n/       strings.json  {KEY: {en, ru}}
assets/     art, ui, audio, fonts, shaders (see assets/README.md)
tools/      generators and harnesses: generate_sfx.py, generate_cards.py, build_theme.gd, build_room.gd,
            selftest.gd, playtest.gd, shot.gd, shot3d.gd
docs/       design and per-system notes
```

Screen flow: `main_menu` -> `lobby` (pick 3 artifacts) -> 3D table -> `result` -> lobby or menu.
The 2D UI base resolution is 640x360 (`canvas_items`, `expand`): pixel art is drawn at 1:1 and scaled by an
integer. The 3D view renders at the window's real resolution.

## 2. Architecture invariants

### Logic never touches nodes, the view never decides rules

- `games/blackjack/blackjack_table.gd` is a `RefCounted`. It owns the shoe, both hands, the bet, the
  phase, and **every rule decision**. It talks to the screen through its own signals.
- `blackjack_view_3d.gd` turns each signal into a **queued animation step** (`core/step_queue.gd`). The
  rules resolve instantly; the screen lags a beat behind so nothing is spoiled (a payout never shows before
  the dealer's last card lands). Input is ignored while the queue runs. Every visible change goes through
  the queue, including numbers, or they would run ahead of the cards. **Pointer input is ignored while the queue runs or
  the hand reaches**, and the queue has a watchdog (`StepQueue.STEP_TIMEOUT`): a step that never finishes is abandoned,
  not allowed to freeze the game. **Never `await tween.finished` on a tween something else may kill** (a killed tween
  never reports): sequence with `await get_tree().create_timer(t).timeout` and a generation counter, as `player_hand_3d.gd` does.
- A new game is a new `games/<name>/` folder with the same shape, a row in `Game.TABLES`, its own artifacts
  in `data/artifacts/<name>/`, and a way to pick it in the lobby.

### The 3D table

- **Performance is a feature, measure it.** `SHOT=table3d_play INFO=1 tools/shot.gd` prints objects, draw
  calls and lights in the frame. Build only what the player can see: every extra mesh is a draw call and every
  extra light multiplies shading on a phone. A column of chips is one striped cylinder (`ChipVisual.make_column`),
  not one mesh per chip; small things cast no shadow; only the table lamp casts one. Current frame: ~200
  objects, ~144 draw calls, 3 lights (the two enforcer characters cost about 25 draw calls; watch phones). All sounds are loaded at startup (`Audio._preload_dir`): a lazy load made
  the first click lag behind the tap.

- Everything is built in code from `blackjack_view_3d.gd`'s layout constants (metres, `TOP` is the felt):
  the table runs **across** the view with the dealer opposite. The chip rack lies along the
  near rim (display only), the action buttons in a row above it, the bet circle in the middle. The artifacts are not on the table:
  they are wedged like coins in the grooves between the fingers of the player's left hand, standing on edge with only the lowest tenth of each coin's height pinched in the grip (`GRIP_SHARE`) (`world/artifact_hand_3d.gd`; each coin sits at a marker that is carried every frame by the two proximal finger bones next to it, so it rides the breathing, the spreading and the other animations), which rests on the
  table at the left of the near edge; the right hand rests at the right. Both are in world space (the room is scaled up,
  a chip is 20 cm, so the hands are 3.5x). The hovered or pinned coin rolls out of the grip, turns to face the player and
  spins (`focus()`); the info panel stays a 2D overlay. Change a position in the view's constants, not in a scene.
- **The hands are editable scenes**, not code: `world/hands/hand_l.tscn` and `hand_r.tscn` hold the unpacked glove (a
  Skeleton3D with 26 finger bones) and an AnimationPlayer with the poses `open`, `fist`, `point`, `tap` and the loops and gestures `idle` (breathing: the fingers close and open in a slow wave, the wrist sways), `clench`, `flat` (palm pressed on the table) and `drum` (the fingers drum). `PlayerHand.gesture(name)` plays one when the hand is free; it also fidgets by itself every 6 to 11 s of idleness, and the view asks for `drum` while the dealer plays, `clench` on a lost hand and `flat` on a push.
  Open them in the editor to pose and animate; `tools/build_hands.gd` regenerates them from `assets/models/hand` and
  **overwrites those edits** (except the left hand, which carries the artifact slots `slot1`..`slot3`, Marker3D nodes placed by hand: the tool leaves it alone, and the coins sit at those markers, bound to the finger bones in code because a marker cannot be bound to a bone in the editor). The scripts only call `play(name)`. The right hand (`world/player_hand_3d.gd`) does
  every press: `BlackjackView3D._act_on` carries it over the felt to the object, taps it and activates the object at
  contact, input is ignored while it reaches. Each death takes a finger of this hand (`set_lives`, `Rules.LIVES` = 5), in one of four scenes
  (`world/finger_cut_3d.gd`, particles plus two CC0 models): the skeleton bites, an enforcer's arm chops it with a cleaver (a CC0 model), the
  finger just bursts into blood and bone (no build-up, no flicker, no prop), a revolver (a CC0 model) held in the left-hand collector's own raised arm shoots it off (the hand lies left of the middle for it) (`Enforcers.begin_gun`: his body stays where it is beside the player, the spine bows and a two-bone reach aims the arm; the gun sits in his palm, a good way short of the finger). Only the bite raises the hand to the camera; for the other three the hand lies flat on
  the table and waits. A death at the deadline (debt) gets the cleaver or the gun; a lost hand (nearly every death) gets any of the four, never the same one twice in a row. The scene calls back at the instant of impact and talks to the view only through signals. The buttons sink into the felt while a finger is lost (`_lose_finger`). **Blood stays**: each hit lays a big splat and 7 to 11 random drops on the felt (`FingerCut._stain`, four procedural splats in one atlas, a quad per stain, at most `MAX_STAINS` = 80, all of them one mesh and one draw call, rebuilt while a splat grows) until the table is gone. `FingerCut.warm_up` draws every prop, splat texture and a light once, tiny, when the table opens, so the first lost finger does not stall (compile the shader before it is needed).
- **A collider that sits in front of another pickable eats its taps**; `pickcheck` catches an overlap.
- **Every control is an object on the table** (`world/pickable_3d.gd`, physics layer 2): plaques,
  artifact tokens. The view casts a ray from the pointer or a tap and calls `activate()` on what it hits. A
  touch arrives as an emulated mouse event, so one code path serves both.
- **Buttons are billboards aligned with the camera's image plane** (`world/plaque_3d.gd`): always an upright,
  unskewed rectangle on screen. A button that merely lies on the table, or turns toward the camera point,
  came out skewed or rolled at the edges. Keep the action row in the middle of the near edge: off-axis
  objects are the most distorted.
- **A hidden plaque must drop its collision** (`collision_layer = 0`): several plaques share one slot, and a
  hidden one would eat the tap meant for the visible one. `tools/shot.gd` with `SHOT=pickcheck` casts a real
  ray at every visible pickable in both phases and must report 0 misses.
- Every pickable answers the pointer: a ring and a glow on hover, a squash and a click on press, a shake and
  a dull tick when it cannot act right now. A tap is never silent (touch has no hover).
- **One tween per pickable** (`Pickable.new_tween()` kills the previous one): an older hide callback must never
  undo a newer show.
- Card faces are the 2D `CardView` rendered once into a tiny `SubViewport` (`world/card_faces.gd`), so the
  3D cards show the same pixel art. Face-up is `rotation.x = 0`, face-down is `PI`.
- The dealer's subtitle (routine lines only with chance `SAY_OFTEN`/`SAY_RARELY`; typed out letter by letter with a low mumble, `_speak`, a generation counter and timers) and the artifact info panel are a 2D overlay on purpose: readable on a phone. The numbers are on the
  table: the purse in gold inlay on the felt (`world/ledger_3d.gd`: chips, counting up and down, and the win streak), the
  installment due above the candles (the total debt is written under it only when an artifact made them differ). There is
  no 2D ledger, so nothing is written twice. Everything the player presses is 3D.
- The room (`world/casino_room.tscn`) is **generated** by `tools/build_room.gd` from primitives: black floor,
  one lamp, ghost tables, neon, dust. Re-running the tool overwrites hand edits; change the layout there.
- The dealer is a KayKit skeleton (`assets/models/dealer`, CC0) driven by `games/blackjack/dealer_3d.gd`.

### Artifacts are data plus a hook script

- `ArtifactData` (a `.tres`) says what it is: kind, rarity, icon, charges, unlock rule. Texts are keys built
  from the id: `ARTIFACT_<ID>_NAME / _DESC / _HINT`.
- `effect_script` extends `ArtifactEffect` and overrides only the hooks it needs: `hand_started`,
  `hand_dealt`, `can_use` / `use` (buttons), `prevent_bust`, `modify_payout`, `modify_payment`, `modify_stake`,
  `modify_deadline`, `modify_new_loan`, `modify_new_debt`, `prevent_death`, `hand_ended`, `rematch`, `allows_credit_double`,
  `modify_offer_size`, `modify_dealer_stands_on`. The table and `RunState` call them at
  fixed points; `docs/GAME_DESIGN.md` has the kind x system matrix of every artifact. **Never patch a rule from outside.**
- A new artifact: write its effect script, its `.tres`, add it to `data/catalog.tres`, add three
  translation keys. Nothing else changes.
- `payout` is the chips returned for the bet (0 on a loss). A curse may return less than 0; the purse
  clamps at 0.

### Meta progress: counters and unlocks

- Gameplay code announces facts through `Events.stat_added` / `Events.stat_peaked` with a name from
  `core/stat.gd`. `Profile` keeps the counters, saves `user://profile.json`, and unlocks an artifact the
  moment `stat(unlock_stat) >= unlock_value`. Fresh unlocks wait in `Profile.fresh_unlocks` for the result
  screen. An artifact with an empty `unlock_stat` is open from the start.
- A locked artifact shows only "Locked" in the collection; no hints or progress are shown anywhere.
- Adding an unlock rule is data only. Adding a new counter is one constant in `Stat` and one emit.

### The run and the artifact offers

- A run starts with **no artifacts**. `Game.start_run(game)` opens a free offer: up to `Rules.OFFER_SIZE` random
  unlocked artifacts the player does not hold, pick one. Another free offer opens **only when a loan is paid
  off** (`RunState.pay_off`). With full slots (`Rules.ARTIFACT_SLOTS`) a pick must name an artifact to replace. Any
  artifact can also be discarded while betting. All of this is `RunState` (`offer_stage`, `choose_offer`,
  `skip_offer`, `discard`, `pay_off`), tested in `selftest.gd`; the view only shows the state.
- **The debt** (`RunState.debt`, numbers in `Rules`): the house lends `Rules.loan_for(n)` chips (150, 300, 600...,
  exponential) and writes a bigger debt down at once, `Rules.debt_for(n)` (250, 625, 1565..., growing faster than the
  loans, so the wins in a row a debt takes climb slowly: 1, 2, 2, 2, 3, 3...). **The stake is always the whole purse**
  (`BlackjackTable.deal_all_in`, the one door the view uses; there are no bet buttons). The debt falls due after
  `PAYMENT_EVERY` hands and is taken from the purse (`next_payment()`, artifacts may shrink it);
  `pay_off()` pays it early. A paid debt hands out the next loan's chips, writes the next debt and opens a free
  artifact offer (`loan_closed` signal). Not enough chips at the deadline is a death unless `prevent_death` saves it, and so is a **lost hand that leaves
  less than the loan** (`hand_finished(bet, lost)`): if more than the loan is left (an artifact gave chips back) no finger is taken.
  **A death costs a life** (`RunState.lives`, `life_lost` signal): the house lends the current loan again, **added to what is left**,
  and the run goes on; the fifth death ends it (`died`).
- The purse is shown as chip columns standing on a rack at the near rim, one per denomination (`world/chip_rack_3d.gd`), display only.
- The debt is physical too: two identical enforcers (a faceless black-suited CC0 base mesh, arms hung down by bone aiming in skeleton space, breathing) stand right and left of the player, level with his seat (mostly out of frame, only the reaching arm comes into view). **The collectors never walk; only the arm and the bow of the spine move.** **They are not drawn or animated while idle** (`_show_gunner`): skinned figures that are mostly out of frame cost a skeleton update and draw calls for nothing; the left-hand one appears for the gun, the right-hand one for the knocks. **A Skeleton3D bone pose is the whole local transform, not a delta on the rest**; they lean in as the
  deadline nears (`world/enforcers_3d.gd`); on the last hand the right-hand one steps up and raps three times on the felt with his own arm, first finger out (`Enforcers.knock`, the same two-bone reach that holds the gun).
- The deadline is physical: `world/deadline_candles_3d.gd` burns one candle per hand toward the payment, the
  dealer's rim light reddens and the vignette darkens as it nears, the last hand has a heartbeat, and the
  payment is three knocks.
- Artifacts are coloured by kind everywhere (`core/kind_style.gd`): active blue, passive green, consumable
  amber, cursed crimson. Effect text uses `+` lines (benefit, green) and `-` lines (cost, red); the info
  panel (`ui/common/artifact_info_panel.gd`, a 2D corner overlay) renders them. Keep descriptions to short lines.
- Buttons have a **cooldown in hands** (`ArtifactData.cooldown_hands`, usually 2 to 4, ticked in `hand_started`), and a
  consumable is removed from the slots the moment its last charge is spent (`RunState.retire_spent`). An undone card
  returns on top of the shoe (`discard_last_player_card`), so the next draw is the same card, and the Lucky Clover lays it face up beside the shoe
  through `peek_next_card`, like the Cracked Mirror. The Marked Deck opens after ten uses of the Cracked Mirror (`Stat.MIRROR_USES`).
- **An artifact announces itself when it acts** (`ArtifactEffect.notify()` -> `RunState.artifact_triggered`): the
  view plays `ui/common/artifact_flash.gd`, the icon popping into the middle of the screen with a shake and
  leaving the same way. Call `notify()` only where the effect really changes something (`modify_payout`,
  `prevent_*`), never in a hook that is also asked just to display a number (`modify_payment` is: such
  artifacts return true from `affects_payment()` and `RunState` notifies when a payment is really taken).
- When an artifact opens, `ui/common/unlock_toast.gd` slides a pop-up in at the bottom-right: icon, name in the
  kind colour and the reason (`ArtifactData.unlock_reason()`, built from the unlock counter via `REASON_<STAT>`
  keys, so a new counter needs one `REASON_` key). It is queued with the table's steps so it never beats the
  animation that earned it. **A wrapping `Label` needs a known width and a frame to settle**: measure a panel
  built from such labels only after two frames, or it keeps an oversized height.
- **A button acts on release**, only if the pointer is still on it (`set_held` sinks it on press); sliding off cancels.
  On touch the first tap on an artifact only shows its panel, the second acts (there is no hover); with a
  mouse the hover shows it and one click acts.

- **The pocket** (`RunState.pocket`, `pocket_capacity()`, `pocket_put/take/swap`, `can_leave`): artifacts put away between hands. They do not work and do not tick, and nothing in the table sees them. Size is `Rules.POCKET_SIZE` + `pocket_bonus` (Deeper Pocket) + `modify_pocket_size` of the artifacts in hand (Smuggler's Coat +2, Clenched Fist -1, which also pays x1.5 on a win); every move is checked so the pocket never overflows (discarding the coat is refused while it would). The view shows wells in a column at the left of the felt (`world/pocket_well_3d.gd`): tap a full well to take it (or to pick the hand artifact to trade it for), an empty one to pick the artifact to put away; Cancel leaves the mode. Pocketed ids are excluded from offers.
- **Credit** (`RunState.credit_owed`): chips borrowed by the Credit Line stay in the debt after a lost finger rewrites it, and are cleared when a payment is made.
- A payment is due every
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

- `tools/selftest.gd`: loads every script, scene and resource, checks translations, plays scripted hands
  against the real rules, then fuzzes random runs with random artifacts.
- `tools/balance.gd`: plays thousands of runs with a basic-strategy bot and prints debts closed per run, hands per run
  and how often the first debt is closed on the first life. **Run it after touching `core/rules.gd`**; the all-in economy
  is sensitive (a hand is a death about half the time, so a run is about ten hands).
- `tools/playtest.gd`: plays a whole run through the real 3D table by activating the real objects on it, while a chaotic
  player mashes presses and releases on random objects, sliding off some (`SEED=n` varies it). It must reach the result.
- `tools/shot.gd`: renders a screen to a PNG (`SHOT=menu|lobby|result|table3d|table3d_play LOCALE=en|ru OUT=...`);
  needs a real driver: `xvfb-run -a -s "-screen 0 1280x720x24" $G --path /tmp/run --rendering-driver opengl3
  --resolution 960x540 --script res://tools/shot.gd`. Headless never compiles a shader or draws a frame.
  Keep 3D shots at 960x540: llvmpipe is slow, and a script error in a harness can hang it, so always wrap it in
  `timeout`.
- In a `--script` harness autoloads are ready only after `await process_frame`, and a harness that names
  an autoload by identifier does not compile: use `root.get_node("Name")`.
- Generated files (`.import`, `.uid`, `ui/theme.tres`, `ui/fonts/*.tres`, `world/casino_room.tscn`) are made
  on the run copy and copied back into the repo **before** the next sync (a sync deletes what the repo lacks). Do not sync the repo over a copy that holds newer `.import` files.
- SVG icons are imported with `svg/scale=0.25` and mipmaps (set in their `.import`); a Button cannot give its
  icon a different filter than its frame, so tiles draw the icon in a child `TextureRect`.

## 4. Working with the code

- After changing a hook signature, grep every effect script that overrides it.
- When behaviour changes, update this file and the matching page in `docs/` in the same commit.
- `tools/generate_sfx.py`, `tools/generate_cards.py` and `tools/generate_gloves.py` (the leather gloves, painted in the hands' UV layout read by `tools/dump_hand_uv.gd`) regenerate procedural assets; edit the script, not
  the output. **A material's emission colour is added to its emission texture**: keep it black when a texture carries the glow.

## 5. Style and conventions

- Comments and docs are in **English**. A comment is a working note: the rule, the number, the trap, why
  not otherwise. Never restate what the line does.
- Do not duplicate numbers that live in code: name the constant (`Rules`).
- Files are `snake_case`; no `class_name`; typed GDScript where it is cheap.
- Bold for hard prohibitions; no shouting.

## 6. Where to look next

- `docs/GAME_DESIGN.md`: decisions, the run loop, the artifact table.
- `assets/README.md`: every asset, its licence and its status.
