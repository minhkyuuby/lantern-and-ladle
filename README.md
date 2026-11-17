# Lantern & Ladle — prototype

Cozy idle night-market restaurant fed by dungeon adventurers. Godot 4.7, GDScript, placeholder art.

## Run
```bash
godot --path .                      # play (or open project.godot in the editor and press F5)
godot --path . -- --fresh --speed=10   # new game at 10x
```
Keys: `Space` pause · `1–4` speed 1×/2×/4×/10× · `Tab` switch Stall/Hollow view · `Esc` close panel · `F1` debug panel (+gold, skip phase, simulate offline, reset).

**Screen:** one view at a time — the **Stall** (a flat side view: kitchen on the left, a long bar on
the right; staff walk behind the counters, customers sit on stools in front) or the **Hollow** (one
corridor per party plus floor cards). Gold, goals, the OPEN sign, day and speed float on top. The
bottom bar opens one management panel at a time (Crew, Hire, Dives, Menu, Pantry, Shop, Legacy, Log)
in a side drawer; a red dot marks panels with something to act on. Click a chef to cheer them on.
The game autosaves every 30 s and on quit (`user://save.json`); on launch it catches up on the time you were away (capped at 8 h).

## Windows
The project has no platform-specific code (GDScript, Compatibility renderer), so on Windows just open
`project.godot` in **Godot 4.7** and press F5. Saves go to `%APPDATA%\Godot\app_userdata\Lantern & Ladle\`.

To build a standalone `LanternAndLadle.exe` (works from macOS too):
1. In the Godot editor: **Editor → Manage Export Templates → Download and Install** (one-time, for 4.7.2).
2. **Project → Export → "Windows Desktop" → Export Project**, or from a terminal:
   ```bash
   godot --headless --path . --export-release "Windows Desktop" build/windows/LanternAndLadle.exe
   ```
The `.pck` is embedded, so the single `.exe` is all you need to share.

## Check
```bash
godot --headless --path . --import
godot --headless --path . --script res://tools/run_tests.gd
godot --headless --path . --script res://tools/balance_sim.gd -- --days=40 [--idle] [--seed=7] [--save]
```
`--save` writes the bot's final state into the game's save slot, so you can jump straight to late-game screens.
`--seasons=6 --days=80` plays several seasons back to back (festival after each Hive Queen) and prints one row per season.
Launching the game with `-- --festival-now` holds the festival immediately if the loaded save allows it (test hook).
Other test hooks: `--view=hollow`, `--panel=dives` (opens a drawer), `--slot=NAME` (separate save file).

## Content
- **Mossy Cellars** (Floors 1–3, boss: the Rat King) — the starting biome.
- **Sunken Orchard** (Floors 4–6, boss: the Hive Queen) — opens after the Rat King once you buy the 🗝 Orchard Expedition Permit. Brings ⚔ Forged Gear (+power for every adventurer, 8 levels) and Merchants (renown 150+).
- **Festival of Lanterns** (prestige, Legacy tab) — after the Hive Queen, end the season: everything resets to day 1 except 🥄 Golden Ladles (5 + √(season earnings / 1000)) and the permanent perks they buy (starting gold, starting levels, faster dives, traffic, XP, dish prices).
- Parties choose floors with **Auto: deepest safe**, **Auto: restock pantry** (the safe floor whose loot covers what the menu is short of; default for Party B) or a fixed floor.

## Story
Story scenes live in `data/story/*.dlg` — a small script format (speaker + expression lines,
`* options`, `~ effects`, `? conditions`, `-> jumps`; the full syntax is in the header of
`sim/story/dialog_parser.gd`). `StoryDirector` queues scenes when their `@trigger` is met (even
offline); they open as focused scenes at 1–2× speed or wait behind the 📖 HUD button at higher speeds.
Choices change affinity, flags and season bonuses. The deep story and choice map are in
`docs/story_bible.md` §7.

Preview a scene: `godot --path . -- --slot=test --fresh --story=ch1_inheritance`

## Art
Placeholder pixel art is drawn in code by `tools/gen_sprites.gd` (characters 16×24, stations 32×20,
ingredient icons 16×16, story portraits 32×32, all shown at 2×). Edit the script, then regenerate:
```bash
godot --headless --path . --script res://tools/gen_sprites.gd
godot --headless --path . --import
```
`docs/sprites_preview.png` is a 4× contact sheet of everything. Anything without a sprite falls back to its emoji.

## Layout
- `sim/` — pure simulation (no nodes): `Sim` clock + `ExpeditionSim`, `RestaurantSim`, `Economy`, `Progression`; `GameState` is everything that gets saved.
- `data/defs/` — Resource classes; `data/content/` — the actual ingredients, recipes, floors, upgrades, customers and `balance.tres` (all tunable numbers). Edit them in the inspector.
- `autoload/game.gd` — runs the sim from real time, speed control, autosave, offline catch-up.
- `scenes/`, `ui/` — views built in code; they only listen to `sim.events` and read state.
