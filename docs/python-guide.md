# ChronoForge — Python Toolchain Guide

> **ChronoForge docs:** [README](../README.md) · **python-guide** · [hardware-guide](hardware-guide.md) · [architecture](hardware-architecture.md)

How to **author a game in Python** and how the **compiler** turns it into the
`.mem` ROMs the FPGA reads. This is the layer that sits *on top of* the hardware —
if you haven't read it yet, [`hardware-guide.md`](hardware-guide.md) explains where
these ROMs go and how the board consumes them.

> **Source of truth:** the code in `tools/`. Field meanings, ranges, and scaling
> below were read from `tools/interpret_langauge/game_class.py` and
> `tools/compiler/json_encoders.py`. Where the old `README.md` / `tools/README.md`
> disagree, this guide follows the code and flags the difference.

---

## Table of contents

1. [Where you work](#1-where-you-work)
2. [Quick start](#2-quick-start)
3. [The compilation pipeline](#3-the-compilation-pipeline)
4. [Authoring API reference](#4-authoring-api-reference)
   - [4.1 GameStage / GameManager](#41-gamestage--gamemanager)
   - [4.2 AttackObject & PlatformObject](#42-attackobject--platformobject)
   - [4.3 GameUIStage / GameUI](#43-gameuistage--gameui)
   - [4.4 CharacterObject](#44-characterobject)
5. [Writing a stage](#5-writing-a-stage)
   - [5.1 More stage examples](#51-more-stage-examples)
6. [Writing a UI stage](#6-writing-a-ui-stage)
   - [6.1 More UI examples](#61-more-ui-examples)
7. [Procedural generation patterns](#7-procedural-generation-patterns)
8. [The GUI previewer](#8-the-gui-previewer)
9. [Compiler implementation (deep)](#9-compiler-implementation-deep)
10. [Font tooling](#10-font-tooling)
11. [Conventions, gotchas & cleanup backlog](#11-conventions-gotchas--cleanup-backlog)

---

## 1. Where you work

As a game author you only touch two folders:

```
tools/main/
├── stage/        ← stage_00.py, stage_01.py, …  (attack + platform objects)
└── stage_ui/     ← stage_ui_00.py, …            (UI config + on-screen text)
```

Each `.py` file defines **one stage** (or one UI stage) by returning a populated
object. Everything else in `tools/` is engine plumbing the compiler runs for you.

**Requirements:** Python 3 (developed on 3.11). The compiler uses only the
standard library; the previewer needs `tkinter` (bundled with CPython); the font
tools need `Pillow` (`pip install pillow`).

---

## 2. Quick start

From the repo root (the scripts add their own paths, so any cwd works):

```bash
# 1. Python classes -> per-stage JSON (also auto-counts objects)
python tools/main/compile_stage_to_json.py

# 2. (optional) Preview object layout & timing in a GUI
python tools/main/open_game_engine_gui.py

# 3. Compile JSON -> the 5 .mem ROMs in /mem  (folds + bit-packs)
python tools/main/compile_stage_to_mem.py
```

Then open Vivado and regenerate the bitstream
([hardware-guide §13](hardware-guide.md#13-vivado-build-flow)). Step 3 is all you
need to ship new game content; the hardware is untouched.

The **stage order on the board** is the ASCII sort order of the filenames in
`stage/` and `stage_ui/` — not the `stage=` number you pass to `GameManager`
(that field is just a label). Name files with zero-padded indices
(`stage_00.py`, `stage_01.py`, …) so the order is unambiguous.

---

## 3. The compilation pipeline

ChronoForge compiles through a "meaning stack" — each layer adds intent while
staying mechanically translatable to the one below:

```
 Python class      JSON source         JSON decode            MEM (ROM)
 (you write)  ──►  (1 file / stage) ─► (1 file / obj-type) ─► (hex/bin for FPGA)
 stage/*.py        json_stage_source/  json-source-decode/    mem/*.mem
 stage_ui/*.py     json_stage_ui_source/
```

| Step | Script (what you run / what runs)                        | In → Out                                                                 |
| ---- | ------------------------------------------------------- | ------------------------------------------------------------------------ |
| A    | `main/compile_stage_to_json.py`                         | `stage/*.py`, `stage_ui/*.py` → `json_stage_source/`, `json_stage_ui_source/` |
| B    | `main/compile_stage_to_mem.py` → `compiler/main_compiler.py` | orchestrates C, D, E                                                  |
| C    | `compiler/source_stage_to_json_compiler.py`            | `json_stage_source/` → `json-source-decode/{game_manager,attack_object,platform_object}.json` |
| D    | `compiler/source_stage_ui_to_json_compiler.py`         | `json_stage_ui_source/` → `json-source-decode/{game_ui,character_object}.json` |
| E    | `compiler/json_to_mem_compiler.py`                     | `json-source-decode/` → `mem/*.mem`                                       |

- **Step A** runs the Python you wrote and serializes each stage to one JSON file
  (per-stage = human-readable, what the GUI previews).
- **Steps C/D** *fold* those per-stage files into per-object-type streams
  (machine-friendly, fixed ROM order), wrapping each list under a `"decimal_data"`
  root key.
- **Step E** bit-packs each stream into a `.mem` ROM.

`font_data.mem` is produced separately by the font tool ([§10](#10-font-tooling)),
not by this pipeline.

---

## 4. Authoring API reference

All classes live in `tools/interpret_langauge/game_class.py`. Ranges/scaling come
from `json_encoders.py`; "HW behavior" notes come from the RTL.

Two scaling rules apply at compile time, so you always write **human units**:

- **Pixels** (`pos_*`, `w`, `h`, bar geometry, HP): stored `value // 4` in 8 bits →
  usable range **0–1020 px** (4-px granularity).
- **Time** (`wait_time`): stored `value * 10` → **0.1 s** steps. ⚠️ `destroy_time`
  is **not** scaled — see [§4.2](#42-attackobject--platformobject).

### 4.1 GameStage / GameManager

`GameStage` is the per-stage container:

```python
stage = GameStage()
stage.game_manager = GameManager(...)      # exactly one
stage.attack_objects.append(AttackObject(...))     # ≥1 required
stage.platform_objects.append(PlatformObject(...)) # ≥1 required
```

`GameManager(...)` fields:

| Field                | Write range      | Scaling | Meaning / HW behavior                                              |
| -------------------- | ---------------- | ------- | ----------------------------------------------------------------- |
| `stage`              | 0–255            | raw 8b  | Scene **label** only (not the play order). Defaults to filename order. |
| `attack_amount`      | *auto*           | 10b     | Set automatically from `len(attack_objects)` — don't pass it.     |
| `platform_amount`    | *auto*           | 10b     | Set automatically from `len(platform_objects)`.                   |
| `wait_time`          | 0–25.5 s         | ×10, 8b | Delay before the next stage, applied after all attacks have spawned. |
| `gravity_direction`  | 0–4              | 3b      | `0` = off. **`1`–`4` all enable gravity (currently pulls *down* regardless)** — the multi-direction case is not yet implemented in `player_position_controller`. |
| `display_pos_x1,y1`  | 0–1020 px        | ÷4, 8b  | Play-area top-left.                                                |
| `display_pos_x2,y2`  | 0–1020 px        | ÷4, 8b  | Play-area bottom-right. All four = 0 → blank screen.              |

### 4.2 AttackObject & PlatformObject

Attacks are **trigger** entities (damage the player); platforms are **collider**
entities (the player stands on them). They share most fields; attacks add
`type` + `colider_type`.

```python
AttackObject(type=0, colider_type=0, movement_direction=2, speed=0,
             pos_x=0, pos_y=0, w=0, h=0,
             wait_time=2, destroy_time=0, destroy_trigger=2)

PlatformObject(movement_direction=2, speed=0, pos_x=0, pos_y=0, w=0, h=0,
               wait_time=0, destroy_time=0, destroy_trigger=2)
```

| Field                | Write range | Scaling | Meaning / HW behavior                                              |
| -------------------- | ----------- | ------- | ----------------------------------------------------------------- |
| `type` *(attack)*    | 0–31        | 5b      | Type/animation **label**. Stored but not used by the current renderer (reserved). |
| `colider_type` *(attack)* | 0–3    | 2b      | Shape label. ⚠️ Stored but unused — collision/render are **rectangular** regardless. (Old docs claim square/circle/oval/etc.) |
| `movement_direction` | 0–7         | 3b      | 8-way: 0=up,1=up-right,2=right,3=down-right,4=down,5=down-left,6=left,7=up-left. |
| `speed`              | 0–31        | 5b      | Sub-pixel speed. `0` = stationary.                                |
| `pos_x`, `pos_y`     | 0–1020 px   | ÷4, 8b  | Spawn top-left.                                                   |
| `w`, `h`             | 0–1020 px   | ÷4, 8b  | Size. `w=h=0` → invisible "null" object (useful as a pure delay). |
| `wait_time`          | 0–25.5 s    | ×10, 8b | Delay before the **next** object spawns (this is your pacing knob). `0` → spawn next almost immediately. |
| `destroy_time`       | 0–255       | **raw, 8b** | Auto-destroy lifetime. ⚠️ **Not ×10** (unlike `wait_time`). One unit ≈ **1 second** (it counts down in the object's own 100 Hz centi-counter). Used when `destroy_trigger = 0`. |
| `destroy_trigger`    | 0–3         | 2b      | `0` = destroy after `destroy_time`; `1` = destroy when it leaves the **play area**; `2` = destroy when it leaves the **screen** (640×480). (Old README's values are wrong.) |

> The `wait_time` ×10 / `destroy_time` ×1 mismatch is in `json_encoders.py`
> (`encode_attack`, `encode_platform`). Documented as-is; decide later whether it's
> a bug to align or intended behavior to keep.

### 4.3 GameUIStage / GameUI

`GameUIStage` is the per-UI-stage container:

```python
stage = GameUIStage()
stage.game_ui = GameUI(...)                              # exactly one
stage.character_objects.append(CharacterObject(...))     # ≥1 required
```

`GameUI(...)` fields:

| Field                            | Write range | Scaling | Meaning / HW behavior                                       |
| -------------------------------- | ----------- | ------- | ---------------------------------------------------------- |
| `show_healt_text`                | 0 / 1       | 1b      | Auto-draw the live `HP ###/###` readout (2- or 3-digit).   |
| `reset_character`                | 0 / 1       | 1b      | Clear previously placed text slots (animation control).    |
| `character_amount`               | *auto*      | 10b     | Set from `len(character_objects)` — don't pass it.         |
| `healt_current`                  | 0–1020      | ÷4, 8b  | Current HP. **`0` = leave HP unchanged** (hardware keeps the running value). |
| `healt_max`                      | 0–1020      | ÷4, 8b  | Max HP (denominator for the bar).                          |
| `transparent_out_screen_display` | 0 / 1       | 1b      | Hide objects outside the play area (saves render work).    |
| `reset_when_dead`                | 0 / 1       | 1b      | When HP hits 0, reset the whole game.                      |
| `healt_bar_pos_x,y`              | 0–1020 px   | ÷4, 8b  | HP bar top-left.                                           |
| `healt_bar_w,h`                  | 0–1020 px   | ÷4, 8b  | HP bar size. `w=h=0` hides the bar.                        |
| `healt_bar_sensitivity`          | 0.00–1.27   | ×100, 7b | Interval between each 1-HP loss while being hit (≈ seconds). **Higher = slower damage.** (Old docs say 0–2.54; the field is 7-bit.) |
| `wait_time`                      | 0–6553.5 s  | ×10, 16b | Delay before the next UI stage (note: 16-bit, far larger than the stage `wait_time`). |

### 4.4 CharacterObject

One on-screen glyph. Constructor is positional `(x, y, char)`:

```python
CharacterObject(character_pos_x=140, character_pos_y=218, character_index="A")
```

| Field             | Write range  | Scaling | Meaning                                              |
| ----------------- | ------------ | ------- | --------------------------------------------------- |
| `character_pos_x` | 0–1020 px    | ÷4, 8b  | Glyph top-left X.                                    |
| `character_pos_y` | 0–1020 px    | ÷4, 8b  | Glyph top-left Y.                                    |
| `character_index` | one char str | 8b      | `A`–`Z` → 0–25, `0`–`9` → 26–35, `/` → 36. Anything else → 255 (blank). Lower-case is upper-cased. |

Each glyph is 17×17 px. There is **no width/height field** (old README §2.5 lists
`w`/`h` — they don't exist; the record is 24 bits, not 32). To render text, place
one `CharacterObject` per visible character (see [§6](#6-writing-a-ui-stage)).

`EntireGame` / `EntireGameUI` are the collection wrappers the compiler uses
internally (`add_stage()` + `export()`); you normally never instantiate them.

---

## 5. Writing a stage

Every `stage/*.py` follows this shape and **must define `stage()`** returning a
`GameStage` (abridged from `tools/main/stage/stage_01.py`):

```python
import sys, os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..')))
from interpret_langauge.game_class import GameStage, GameManager, AttackObject, PlatformObject


def stage():
    stage = GameStage()

    # One manager: no player display this stage, 1 s before the next stage
    stage.game_manager = GameManager(stage=1, wait_time=1, gravity_direction=0,
                                     display_pos_x1=0, display_pos_y1=0,
                                     display_pos_x2=0, display_pos_y2=0)

    # A 2-second opening delay (null object: w=h=0, just burns wait_time)
    stage.attack_objects.append(
        AttackObject(movement_direction=2, speed=0, pos_x=0, pos_y=0, w=0, h=0,
                     wait_time=2, destroy_time=0, destroy_trigger=2))

    # 6 rows × 10 blocks, generated with a loop (see §7)
    def generate_row(y):
        stage.attack_objects.extend([
            AttackObject(movement_direction=0, speed=0,
                         pos_x=85 + 50*i, pos_y=y, w=20, h=20,
                         wait_time=0, destroy_time=4, destroy_trigger=2)
            for i in range(10)])
    for i in range(6):
        generate_row(140 + 50*i)

    # Platforms need ≥1 entry even if unused → a null placeholder
    stage.platform_objects.append(
        PlatformObject(movement_direction=2, speed=0, pos_x=0, pos_y=0, w=0, h=0,
                       wait_time=0, destroy_time=0, destroy_trigger=2))

    return stage
```

Design order that works well in practice:

1. Set the **play area** (`display_pos_*`) and **gravity** in `GameManager`.
2. Lay out the **attack timeline** — this is the global clock; its total
   `wait_time` decides when the stage ends.
3. Add **platforms last**, sizing their `destroy_time`/`wait_time` to outlive the
   attack waves they belong to (a platform that dies early disappears mid-stage).

The first `import sys/os` header is mandatory — it puts `tools/` on the path so
`interpret_langauge.game_class` resolves when the compiler imports your file.

### 5.1 More stage examples

Two patterns lifted from real stages. (The `import` header from above is assumed;
shown trimmed for focus.)

**Showcase A — a marching wave that fans out.** Three waves of 10 falling blocks
(`movement_direction=4` = down). Each wave is faster than the last, and `speed`
ramps across the row (`base_speed + i`) so the wave spreads instead of staying a
flat line:

```python
def stage():
    stage = GameStage()
    stage.game_manager = GameManager(stage=1, wait_time=1, gravity_direction=0,
                                     display_pos_x1=0, display_pos_y1=0,
                                     display_pos_x2=0, display_pos_y2=0)

    SIZE, GAP, X0, Y = 20, 30, 85, 140

    # 2 s opening pause (null object: w=h=0, just burns wait_time)
    stage.attack_objects.append(
        AttackObject(movement_direction=2, speed=0, pos_x=0, pos_y=0, w=0, h=0,
                     wait_time=2, destroy_time=0, destroy_trigger=2))

    def wave(base_speed):
        stage.attack_objects.extend([
            AttackObject(movement_direction=4, speed=base_speed + i,
                         pos_x=X0 + (SIZE + GAP) * i, pos_y=Y, w=SIZE, h=SIZE,
                         wait_time=0, destroy_time=4, destroy_trigger=2)
            for i in range(10)])
    for w in range(3):
        wave(base_speed=w * 10)

    # tail pause so the last wave clears before the stage loops
    stage.attack_objects.append(
        AttackObject(movement_direction=2, speed=0, pos_x=0, pos_y=0, w=0, h=0,
                     wait_time=7, destroy_time=0, destroy_trigger=2))

    stage.platform_objects.append(            # required ≥1 placeholder
        PlatformObject(movement_direction=2, speed=0, pos_x=0, pos_y=0, w=0, h=0,
                       wait_time=0, destroy_time=0, destroy_trigger=2))
    return stage
```

**Showcase B — a gravity gauntlet of closing walls.** Gravity is on
(`gravity_direction=3`), so the player falls to the floor and must line up with a
gap. Each beat spawns a left+right pair of walls *outside* the play box that slide
inward (`2` = right, `6` = left); every wall is split into a tall upper bar and a
short lower bar, leaving a `GAP` to slip through. Geometry is read back off the
`GameManager` so the walls always hug the current play area:

```python
def stage():
    stage = GameStage()
    stage.game_manager = GameManager(stage=1, wait_time=1, gravity_direction=3,
                                     display_pos_x1=136, display_pos_y1=256,
                                     display_pos_x2=508, display_pos_y2=384)
    gm = stage.game_manager

    SPEED, BAR_W, GAP = 12, 12, 22
    HEIGHTS  = [20, 40, 60]                  # small / medium / large
    SEQUENCE = [0, 2, 1, 0, 1, 1, 2, 0]      # the height each pair uses

    LEFT_X, RIGHT_X = gm.display_pos_x1 - BAR_W, gm.display_pos_x2
    TOP_Y,  BOT_Y   = gm.display_pos_y1, gm.display_pos_y2
    H = BOT_Y - TOP_Y

    stage.attack_objects.append(             # 3 s intro
        AttackObject(movement_direction=2, speed=0, pos_x=0, pos_y=0, w=0, h=0,
                     wait_time=3, destroy_time=0, destroy_trigger=2))

    def wall_pair(bar_h, right_delay):
        upper_h = H - bar_h - GAP
        stage.attack_objects.extend([
            # left lower, left upper, right lower, right upper (last one delayed)
            AttackObject(movement_direction=2, speed=SPEED, pos_x=LEFT_X,
                         pos_y=BOT_Y - bar_h, w=BAR_W, h=bar_h,
                         wait_time=0, destroy_time=20, destroy_trigger=2),
            AttackObject(movement_direction=2, speed=SPEED, pos_x=LEFT_X,
                         pos_y=TOP_Y, w=BAR_W, h=upper_h,
                         wait_time=0, destroy_time=20, destroy_trigger=2),
            AttackObject(movement_direction=6, speed=SPEED, pos_x=RIGHT_X,
                         pos_y=BOT_Y - bar_h, w=BAR_W, h=bar_h,
                         wait_time=0, destroy_time=20, destroy_trigger=2),
            AttackObject(movement_direction=6, speed=SPEED, pos_x=RIGHT_X,
                         pos_y=TOP_Y, w=BAR_W, h=upper_h,
                         wait_time=right_delay, destroy_time=20, destroy_trigger=2),
        ])

    for idx in SEQUENCE:
        wall_pair(bar_h=HEIGHTS[idx], right_delay=1.5)

    stage.platform_objects.append(
        PlatformObject(movement_direction=2, speed=0, pos_x=0, pos_y=0, w=0, h=0,
                       wait_time=0, destroy_time=0, destroy_trigger=2))
    return stage
```

---

## 6. Writing a UI stage

Every `stage_ui/*.py` returns a `GameUIStage` from `stage()`
(from `tools/main/stage_ui/stage_ui_01.py`):

```python
import sys, os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..')))
from interpret_langauge.game_class import GameUIStage, GameUI, CharacterObject
from main.stage_ui import center_data            # shared layout constants

def stage():
    stage = GameUIStage()

    stage.game_ui = GameUI(show_healt_text=0, reset_character=0,
                           healt_current=0, healt_max=0,
                           healt_bar_w=0, healt_bar_h=0,
                           healt_bar_sensitivity=0, wait_time=1.5)

    # Render the word "IS" as individual glyphs, skipping spaces
    stage.character_objects.extend([
        CharacterObject(140 + (center_data.CHARACTER_W + center_data.GAP) * (i + 5), 218, ch)
        for i, ch in enumerate("IS ")
        if ch != " "
    ])

    return stage
```

`center_data.py` holds shared spacing constants (`CHARACTER_W = 17`, `GAP = 1`) so
text columns line up across UI stages. The "write a string as a list of glyphs"
idiom above is the standard way to draw text; `if ch != " "` skips spaces so they
cost no character slots.

The live HP readout (`show_healt_text=1`) is generated by the hardware, not by you
— you only place *static* text via `CharacterObject`.

### 6.1 More UI examples

**Showcase A — a live combat HUD.** Set HP to `100/100`, draw a bar, and turn on
the auto `HP ###/###` readout. This is the one case where a UI stage needs **no**
hand-placed glyphs: with `show_healt_text=1` the hardware fills the character slots
with the live HP digits for you. `reset_character=1` clears any text left over from
the previous UI stage:

```python
def stage():
    stage = GameUIStage()

    stage.game_ui = GameUI(
        show_healt_text=1,            # auto-draw the live HP ###/### readout
        reset_character=1,            # clear text from the previous UI stage
        transparent_out_screen_display=1,
        reset_when_dead=1,            # HP 0 -> reset the whole game
        healt_current=100, healt_max=100,
        healt_bar_pos_x=140, healt_bar_pos_y=60,
        healt_bar_w=200, healt_bar_h=16,
        healt_bar_sensitivity=0.04,   # ~0.04 s between each 1-HP tick while hit
        wait_time=30)                 # hold the HUD while the fight plays out

    return stage
```

**Showcase B — a centered, multi-line title card.** A small `line()` helper draws
any word as a row of glyphs (skipping spaces), so stacking lines is just two
`extend` calls at different `y`:

```python
def stage():
    stage = GameUIStage()
    stage.game_ui = GameUI(show_healt_text=0, reset_character=1,
                           healt_current=0, healt_max=0,
                           healt_bar_w=0, healt_bar_h=0,
                           healt_bar_sensitivity=0, wait_time=2)

    W, GAP = center_data.CHARACTER_W, center_data.GAP     # 17, 1

    def line(text, x0, y):
        return [CharacterObject(x0 + (W + GAP) * i, y, ch)
                for i, ch in enumerate(text) if ch != " "]

    stage.character_objects.extend(line("GAME OVER",   x0=180, y=200))
    stage.character_objects.extend(line("PRESS RESET", x0=170, y=230))
    return stage
```

> The font only covers `A`–`Z`, `0`–`9`, and `/` ([§4.4](#44-characterobject)), so
> keep title text within that set — any other glyph renders blank.

---

## 7. Procedural generation patterns

Objects live in plain Python lists, so build them with normal Python. This is the
whole point of authoring in code rather than hand-writing ROM:

```python
# append in a for-loop
for i in range(10):
    stage.attack_objects.append(AttackObject(pos_x=80*i, pos_y=100, w=20, h=20,
                                             wait_time=0, destroy_time=4, destroy_trigger=2))

# extend with a comprehension (same result, denser)
stage.attack_objects.extend([
    AttackObject(pos_x=80*i, pos_y=100, w=20, h=20, wait_time=0,
                 destroy_time=4, destroy_trigger=2)
    for i in range(10)])

# factor repeated layouts into helper functions
def column(x):
    return [AttackObject(pos_x=x, pos_y=60*j, w=20, h=20, wait_time=0,
                         destroy_time=4, destroy_trigger=2) for j in range(8)]
for x in range(100, 500, 80):
    stage.attack_objects.extend(column(x))
```

Great for bullet-hell patterns, repeated platforms, and symmetric/parametric
layouts. Remember: `wait_time` on an object paces the spawn of the **next** object,
so interleave null/delay objects to control timing between bursts.

---

## 8. The GUI previewer

`python tools/main/open_game_engine_gui.py` launches
`tools/python_gui/stage_viewer.py`, a tkinter tool that reads the **per-stage**
JSON in `json_stage_source/` (so run step A first). It shows:

- the **display area** (gold rectangle) from `game_manager`;
- **attack** objects (red) and **platform** objects (blue), drawn at the same
  `//4` granularity the hardware uses;
- a **stage selector**, an object list, and a "Highlight N" control to step
  through `N` consecutive objects (handy for checking spawn order/pacing).

It's read-only — a visual sanity check before you spend a Vivado build. It does not
preview UI stages or live timing.

---

## 9. Compiler implementation (deep)

For when you need to change *how* compilation works.

### 9.1 Step A — `compile_stage_to_json.py`

Globs `stage/stage_*.py` (sorted), imports each module, calls its `stage()`, and
feeds the result to `EntireGame`. `EntireGame.export()` writes one
`stage{i:02}.json` per entry to `json_stage_source/` — **`i` is the enumeration
index**, i.e. filename sort order defines play order. The same is repeated for
`stage_ui/` → `EntireGameUI` → `json_stage_ui_source/`.

`GameStage.to_dict()` auto-fills `attack_amount`/`platform_amount` from list
lengths (and `GameUIStage.to_dict()` fills `character_amount`) — this is why you
never set those by hand.

### 9.2 Steps C/D — the folding compilers

`source_stage_to_json_compiler.py` reads every `json_stage_source/stage*.json`
(sorted), and folds:
- one `game_manger` entry per stage → `game_manager` master list;
- all `attack_object[]` → `attack_object` master list (concatenated in stage order);
- all `platform_object[]` → `platform_object` master list.

Each output is written under a `{"decimal_data": [...]}` root key to
`json-source-decode/`. `source_stage_ui_to_json_compiler.py` does the same for
`game_ui` + `character_object`. Folding is what flattens "scene-centric" data into
the "object-type-centric" ROM order the hardware expects.

> Note the input key is the misspelled `"game_manger"` — it threads through
> `game_class.py` → these compilers → the GUI. Don't rename it in one place only.

### 9.3 Step E — `json_to_mem_compiler.py` + `json_encoders.py`

`build_mem_files()` runs five tasks (one per ROM), each reading
`json-source-decode/<name>.json["decimal_data"]`, encoding every entry, and writing
`mem/<name>.mem`:

```python
for idx, entry in enumerate(data_list):
    bitstring = task["encoder"](entry, idx)        # encode_* in json_encoders.py
    line = bin_to_hex(bitstring)                   # → hex ROM line
```

`json_encoders.py` owns the bit layout. `pack_bits(value, width, …)` masks each
field to its width (and warns on overflow); `bin_to_hex()` packs the row to hex.
**These widths must match the Verilog ROM-reader bit-slices exactly** — change one,
change the other ([hardware-architecture §4.2](hardware-architecture.md#42-rom-readers)).

| ROM                   | Encoder               | Row width |
| --------------------- | --------------------- | --------- |
| `game_manager.mem`    | `encode_game_manager` | 72 bits   |
| `attack_object.mem`   | `encode_attack`       | 72 bits   |
| `platform_object.mem` | `encode_platform`     | 64 bits   |
| `game_ui.mem`         | `encode_ui`           | 88 bits   |
| `character_object.mem`| `encode_character`    | 24 bits   |

**EOF closer:** for `game_manager` and `game_ui` only, the compiler appends one
all-ones row (`"1"*width`). The hardware reads this as `is_end` (`&rom[addr]`) to
loop the game/UI back to index 0. The other ROMs get no closer.

`build_mem_files(isPushingVerilog, isHex)` can target `tools/mem-decode/` and emit
raw binary instead of hex for debugging, but the default run writes hex into the
real `mem/`.

---

## 10. Font tooling

The 17×17 bitmap font (`mem/font_data.mem`) is generated **outside** the main
pipeline, by `systhesis/gen_font_mem.py` (`pip install pillow` required):

- Reads `systhesis/17x17_font_data/<char>.jpg` for `a`–`z` then `0`–`10` (37
  images), thresholds each at grayscale < 128 → `1` (ink) / `0`, and writes 17
  rows of 17 bits per glyph to `mem/font_data.mem`.
- Output is **binary text** (0/1), because the hardware loads it with `$readmemb`
  (not `$readmemh` like the others) — keep it that way.
- Glyph index order matches `CharacterObject`: index 0 = `a.jpg` (= `A`), … index
  36 = `10.jpg`, which holds the **`/`** glyph (that's why `character_index "/"` →
  36). It's only regenerated if you redraw the font.

`systhesis/decode_mem_to_jpg.py` is the inverse — it renders `font_data.mem` back
to JPGs in `systhesis/decoded_jpg/` so you can eyeball that the ROM is correct.

---

## 11. Conventions, gotchas & cleanup backlog

Documented honestly so the revival goes smoothly. **Not fixed here — docs only.**

- **`destroy_time` is not ×10 scaled** while `wait_time` is
  ([§4.2](#42-attackobject--platformobject)). Subtle and easy to trip over.
- **`healt_bar_sensitivity` max is 1.27** (7-bit ×100), not 2.54.
- **`gravity_direction` 1–4 all just pull down** today; multi-direction gravity
  isn't implemented in the player controller.
- **`colider_type` and `type` are stored but unused** — collision/render are
  rectangular. Reserved fields.
- **Misspelled but load-bearing names:** the package `interpret_langauge`, the JSON
  key `game_manger`, and the folder `systhesis`. Each is referenced from multiple
  files; rename only as a coordinated pass, then re-run the full pipeline.
- **`tools/temp/`** is scratch (old stage copies, `test.py`) — not part of the
  pipeline; safe to ignore/remove.
- **`stage_ui/` has gaps** (no `18`, `30`, `31`) and an odd `stage_ui_0.py`. Order
  still works (ASCII sort), but it reads as unfinished.
- **`__pycache__/` is committed** across `tools/` — should be git-ignored.
- Minor: `compile_stage_to_json.py` reuses the variable name `STAGE_UI_DIR` for
  both the `stage` and `stage_ui` passes (harmless, just confusing).
