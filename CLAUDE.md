# CLAUDE.md

Project map and working notes for the **ChronoForge FPGA Engine**. Read this first.

## What this project is

ChronoForge is a **pure-hardware 2D game engine** that runs entirely on a Xilinx
Basys3 FPGA (Artix-7) — no CPU, no ISA, no OS. Game logic is preprocessed on a PC
into fixed-width hex ROM images (`.mem`) and executed directly by event-driven
Verilog circuits at 640×480 @ 60 Hz.

Two halves live in one repo:

1. **Verilog hardware** (`verilog/`, `vivado/`) — the runtime that runs on the board.
2. **Python toolchain** (`tools/`) — authoring + compiler that turns Python game
   definitions into the `.mem` ROMs the hardware reads.

The bridge between them is the `mem/*.mem` files, which the Vivado project loads
into BRAM at synthesis time.

## The data pipeline (most important mental model)

```
stage/*.py  ─┐                      compile_stage_to_json.py
stage_ui/*.py┘  (Python classes) ───────────────────────────► json_stage_source/
                                                                json_stage_ui_source/
                                       main_compiler.py
                (JSON "scene" source) ───────────────────────► json-source-decode/
                                       (object-type-centric JSON)
                                       json_to_mem_compiler.py
                                     ───────────────────────────► mem/*.mem
                                       (Vivado loads these into BRAM)
```

Meaning stack: **Python class → JSON source (one file per stage) → JSON decode
(one file per object type) → MEM (hex ROM) → FPGA**.

## Build / run commands

Run with the system Python (uses only stdlib + tkinter). Scripts add their own
paths, so they work from any cwd.

```bash
# 1. Python classes -> JSON source (also auto-fills attack/platform/character counts)
python tools/main/compile_stage_to_json.py

# 2. Visually preview stage object layout/timing (tkinter GUI)
python tools/main/open_game_engine_gui.py

# 3. Full compile JSON -> .mem ROMs in /mem (runs main_compiler.py: fold + bit-pack)
python tools/main/compile_stage_to_mem.py

# Regenerate the 17x17 bitmap font ROM from images (rarely needed)
python systhesis/gen_font_mem.py
```

Then in Vivado: open `vivado/ChronoForge.xpr` → Synthesis → Implementation →
Generate Bitstream → Program device. The `.mem` files are already wired into the
project, so step 3 is all that's needed to push new game data.

## Repository layout

```
ChronoForge-FPGA-Engine/
├── README.md / README_thai.md   Project spec & user guide (EN / TH — TH is stale)
├── mem/                         FINAL compiled ROMs loaded by Vivado (6 .mem files)
├── docs/images/                 Screenshots used by the README
├── systhesis/                   [sic] Font tooling: gen_font_mem.py, image sets
├── tools/                       Python toolchain
│   ├── main/                    >>> Game-author workspace (edit here) <<<
│   │   ├── stage/               stage_00.py … : attack + platform objects per stage
│   │   ├── stage_ui/            stage_ui_*.py : UI config + character (text) objects
│   │   ├── compile_stage_to_json.py
│   │   ├── compile_stage_to_mem.py
│   │   └── open_game_engine_gui.py
│   ├── interpret_langauge/      [sic] game_class.py = the authoring API (classes)
│   ├── compiler/                main_compiler.py + json_encoders.py + 2 folders
│   ├── python_gui/              stage_viewer.py (the tkinter previewer)
│   ├── json_stage_source/       generated: one JSON per stage
│   ├── json_stage_ui_source/    generated: one JSON per UI stage
│   ├── json-source-decode/      generated: one JSON per object type
│   └── temp/                    SCRATCH/JUNK — not part of the pipeline
├── verilog/
│   ├── constrains/constains.xdc [sic] Pin mapping (edit for non-Basys3 boards)
│   ├── simulation/              testbenches
│   └── sources/                 23 RTL modules (see hardware map below)
└── vivado/                      Vivado project (ChronoForge.xpr) + build junk
```

Note the misspelled-but-real paths: `systhesis/`, `interpret_langauge/`,
`constrains/constains.xdc`. Use them verbatim until/unless they are renamed.

## Hardware architecture (`verilog/sources/`)

`top/topModule.v` instantiates everything. Design is **decentralized**: each
runtime owns a clock domain and a single responsibility; modules talk via a
two-wire `sync_*` (active-low request) / `update_*` (active-high done) handshake.

| Folder         | Key modules                                                              |
| -------------- | ------------------------------------------------------------------------ |
| `top/`         | `topModule.v` (root), `clk_div.v`                                         |
| `runtime/`     | `main_game_runtime`, `game_ui_runtime`, `multi_object_{collider,trigger,...}_runtime` |
| `rom_reader/`  | one reader per ROM: attack / platform / character / game_manager / game_ui / font_data |
| `object/`      | `object_position_controller`, `object_renderer` (instanced per object)   |
| `player/`      | `player_position_controller`, `player_properties_controller`, `player_renderer` |
| `game_display/`| `game_display_controller`, `game_display_renderer`                        |
| `peripherals/` | `vga_translator`, `universal_renderer` (final priority pixel mux)         |

Three independent **timelines** (ROM index counters) drive gameplay: Attack,
Platform, Character. The Attack timeline is the global epoch — when it hits the
`0xFFFFF` EOF header, the whole game resets.

### Clock domains (derived from 100 MHz `clk`, see `topModule.v` localparams)

| Clock                | `topModule` divisor       | Frequency | Drives                          |
| -------------------- | ------------------------- | --------- | ------------------------------- |
| `clk_vga`            | `CLK_DIV_FACTOR_VGA=4`    | 25 MHz    | VGA 640×480 timing              |
| `clk_player_control` | `=1_000_000`              | 100 Hz    | player input/physics            |
| `clk_object_control` | `=1_000_000`              | 100 Hz    | object movement                 |
| `clk_centi_second`   | `=1_000_000`              | 100 Hz    | `wait_time`/`destroy_time`      |
| `clk_calculation`    | `=100_000`                | 1 kHz     | sync, collision, ROM updates    |

> ⚠️ The READMEs narrate `clk_centi_second` as 1 kHz / millisecond, but the
> committed divisor (`1_000_000`) yields 100 Hz. Treat `topModule.v` as the
> source of truth and reconcile the docs.

### Resource-allocation knobs (in `topModule.v`)

- `MAXIMUM_COLLIDER_OBJECT_AMOUT = 25`  (note: real spelling is `AMOUT`)
- `MAXIMUM_TRIGGER_OBJECT_AMOUT = 56`
- `MAXIMUM_UI = 20` (character/UI slots — there is **no** `MAXIMUM_CHARACTER_AMOUNT`)

These set instanced object counts and dominate LUT/FF/BRAM usage. README's config
section lists different names/values — trust the code.

## ROM / bit-packing formats

**Source of truth = `tools/compiler/json_encoders.py`.** Each `encode_*` function
defines field order, scaling, and width. Current totals:

| ROM (`mem/*.mem`)     | Encoder              | Width   | Notes                                  |
| --------------------- | -------------------- | ------- | -------------------------------------- |
| `game_manager.mem`    | `encode_game_manager`| 72 bits | + all-ones `0xFFF…` EOF closer appended |
| `attack_object.mem`   | `encode_attack`      | 72 bits |                                        |
| `platform_object.mem` | `encode_platform`    | 64 bits |                                        |
| `game_ui.mem`         | `encode_ui`          | 88 bits | + EOF closer appended                  |
| `character_object.mem`| `encode_character`   | 24 bits | only pos_x, pos_y, index (no w/h)      |
| `font_data.mem`       | `systhesis/gen_font_mem.py` | 17×17 | bitmap glyph font                |

Scaling conventions enforced by the encoders:
- pixel fields (`pos_x/y`, `w/h`, hp-bar geometry) are stored `value // 4` (8-bit, 0–1023 px range).
- time fields (`wait_time`, `destroy_time`) are stored `value * 10` (seconds → ticks).

> ⚠️ The README/`tools/README.md` bit tables disagree with the encoders in several
> places (e.g. character listed as 32-bit/5-field; game_manager as 74-bit). When
> docs and `json_encoders.py` conflict, the code wins.

## Conventions & gotchas

- **Game authors only edit `tools/main/stage/*.py` and `tools/main/stage_ui/*.py`.**
  Everything else is engine internals.
- Stage/UI ordering is **ASCII filename order**; each file must expose a `stage()`
  function returning a `GameStage` / `GameUIStage`. Each list needs ≥1 object.
- `attack_amount` / `platform_amount` / `character_amount` are auto-filled from list
  length in `to_dict()` — don't set them by hand.
- A stage advances when its **attack** timeline finishes; a UI stage advances when
  its **character** timeline finishes. Watch platform/UI lifetimes vs. attack pacing.
- Many committed files are **build junk** (`__pycache__/`, `tools/temp/`,
  `vivado/.Xil/`, `vivado/*.zip`, `tempCodeRunnerFile.py`). Don't treat them as
  source. `.gitignore` currently misses most of these.
- This is `git user: Night`; default branch `main`. Commit/push only when asked.

## Doc status (as of 2026-06)

`README.md` is a large hand-written spec (~1500 lines) that is mostly excellent but
has drifted from the code (bit widths, clock freqs, param names, char format).
`README_thai.md` is a much shorter, stale translation (left as-is for now).
`tools/README.md` is an older compiler doc with outdated bit tables.

Focused guides (verified against code, treat as authoritative):
- `docs/hardware-guide.md` — Vivado/Verilog usage, build, config, `.mem` wiring. **Done.**
- `docs/hardware-architecture.md` — deep dive: every module + inter-core comms. **Done.**
- `docs/python-guide.md` — authoring API, stage/UI authoring, compiler internals, font tooling. **Done.**

Verify any numeric claim against the code before repeating it.
