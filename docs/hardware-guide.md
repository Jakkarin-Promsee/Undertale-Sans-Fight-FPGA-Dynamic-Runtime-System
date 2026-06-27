# ChronoForge — Hardware Guide (Vivado / Verilog)

How the FPGA side of ChronoForge is built, how to run it on a board, and how to
configure it. This is the **foundation layer** — the Python toolchain (see the
upcoming `python-guide.md`) only produces the `.mem` ROMs that this hardware reads.

> **Source of truth:** the RTL in `verilog/sources/` and the Vivado project in
> `vivado/`. Where the top-level `README.md` and this guide ever disagree on a
> number, trust the code. Every value below was read from the RTL, not copied
> from older docs.

---

## Table of contents

1. [Target & toolchain](#1-target--toolchain)
2. [Quick start (run it on a board)](#2-quick-start-run-it-on-a-board)
3. [Top module I/O & pin map](#3-top-module-io--pin-map)
4. [Architecture overview](#4-architecture-overview)
5. [Module hierarchy](#5-module-hierarchy)
6. [Clock domains](#6-clock-domains)
7. [Sync / update handshake](#7-sync--update-handshake)
8. [Data path: ROM → runtime → pixels](#8-data-path-rom--runtime--pixels)
9. [Rendering pipeline](#9-rendering-pipeline)
10. [Object autonomy & movement](#10-object-autonomy--movement)
11. [Player & physics](#11-player--physics)
12. [Configuration reference](#12-configuration-reference)
13. [Vivado build flow](#13-vivado-build-flow)
14. [Simulation](#14-simulation)
15. [Resource utilization](#15-resource-utilization)
16. [Known quirks & cleanup backlog](#16-known-quirks--cleanup-backlog)

---

## 1. Target & toolchain

| Item             | Value                                                            |
| ---------------- | --------------------------------------------------------------- |
| Board            | Digilent **Basys3**                                             |
| FPGA part        | `xc7a35tcpg236-1` (Xilinx Artix-7)                              |
| Project file     | `vivado/ChronoForge.xpr`                                        |
| Created with     | Vivado **2015.4**                                               |
| HDL              | Plain Verilog-2001 (`verilog/sources/`), no vendor IP cores     |
| Top module       | `topModule` (`verilog/sources/top/topModule.v`)                |
| Display output   | VGA 640×480 @ 60 Hz, 12-bit color (4-4-4)                       |
| Input            | 4 directional push buttons + 1 reset switch                    |

Because the design is portable Verilog with no IP, it opens in newer Vivado via
the usual project-upgrade prompt. The only board-specific file is the constraints
(`.xdc`); see [§12.1](#121-pin-mapping-xdc).

---

## 2. Quick start (run it on a board)

To just rebuild and run the current game on a Basys3:

1. Open `vivado/ChronoForge.xpr` in Vivado.
2. **Generate Bitstream** (runs synthesis + implementation automatically).
3. Connect the Basys3 over USB, open **Hardware Manager → Program Device**.
4. Connect a VGA cable to a monitor. The game starts immediately.
5. Controls: the four push buttons move the player; slide switch **SW0** is reset.

To change the *game content* (levels, attacks, UI), you do **not** touch Verilog —
you regenerate the `.mem` ROMs with the Python toolchain, then re-run step 2. The
six `.mem` files in `mem/` are already added to the Vivado project as design
sources, so a fresh bitstream picks them up. See
[§8](#8-data-path-rom--runtime--pixels) for how the ROMs are loaded.

---

## 3. Top module I/O & pin map

`topModule` ports (`verilog/sources/top/topModule.v`) and their Basys3 pin
assignments (`verilog/constrains/constains.xdc`, all `LVCMOS33`):

| Port            | Dir | Basys3 location | Pin   | Notes                                  |
| --------------- | --- | --------------- | ----- | -------------------------------------- |
| `clk`           | in  | 100 MHz osc     | `W5`  | `create_clock -period 10.000` (100 MHz) |
| `clk_reset`     | in  | switch SW0      | `V17` | active-high synchronous reset           |
| `switch_up`     | in  | button BTNU     | `T18` | player up / jump                        |
| `switch_down`   | in  | button BTND     | `U17` | player down                             |
| `switch_left`   | in  | button BTNL     | `W19` | player left                             |
| `switch_right`  | in  | button BTNR     | `T17` | player right                            |
| `HS`            | out | VGA HSync       | `P19` | active-low sync                         |
| `VS`            | out | VGA VSync       | `R19` | active-low sync                         |
| `RED[3:0]`      | out | VGA red         | `G19 H19 J19 N19` |                              |
| `GREEN[3:0]`    | out | VGA green       | `J17 H17 G17 D17` |                              |
| `BLUE[3:0]`     | out | VGA blue        | `N18 L18 K18 J18` |                              |

`topModule` also has a compile-time parameter `IS_SIM` (default `0`); set to `1`
only for simulation to shrink the clock dividers (see [§14](#14-simulation)).

---

## 4. Architecture overview

ChronoForge is a **decentralized, multi-clock, event-driven** design. There is no
CPU and no instruction stream. Instead:

- Game data is pre-compiled into fixed-width hex ROMs (`.mem`) and read directly.
- Each *runtime* owns one responsibility and runs in its own clock domain.
- Modules coordinate through a simple two-wire handshake (`sync_*` / `update_*`).
- Gameplay is organized as three independent **timelines** — Attack, Platform,
  Character — each just a ROM index counter that advances when its per-object
  `wait_time` elapses.

The **Attack timeline is the global epoch.** When the game manager ROM hits its
end-of-list marker (`is_end`, the all-ones `0xFFF…` closer row) — or the player
dies — `game_runtime` resets `current_stage` to 0 and the whole game restarts
(`verilog/sources/runtime/main_game_runtime.v`).

> Note: in the current code, only the **attack** count drives stage transitions.
> The matching platform-transition branch is commented out in
> `main_game_runtime.v`, so platforms ride along inside the stage the attack
> timeline defines.

---

## 5. Module hierarchy

23 RTL modules under `verilog/sources/`. Functional grouping:

```
topModule  (top/topModule.v)  ── instantiates everything below
│
├── clk_div ×5                 (top/clk_div.v)            clock generation
├── vga_translator             (peripherals/)            640×480 timing, x/y/blank
│
├── game_runtime               (runtime/main_game_runtime.v)   STAGE timeline + FSM
│   └── game_manager_rom       (rom_reader/)             per-stage config ROM
├── attack_object_rom          (rom_reader/)             attack ROM reader
├── platform_object_rom        (rom_reader/)             platform ROM reader
│
├── multi_object_trigger_runtime   (runtime/)            N attack objects (parallel)
│   └── [generate ×N] object_position_controller + object_renderer
├── multi_object_collider_runtime  (runtime/)            N platform objects (parallel)
│   └── [generate ×N] object_position_controller + object_renderer
│
├── game_ui_runtime            (runtime/game_ui_runtime.v)  UI/CHARACTER timeline
│   ├── game_ui_rom_reader     (rom_reader/)
│   ├── character_object_rom_reader (rom_reader/)
│   └── font_data_rom_reader   (rom_reader/)             17×17 bitmap font
│
├── game_display_controller / game_display_renderer  (game_display/)  play-area box
├── player_position_controller / player_properties_controller / player_renderer (player/)
└── universal_renderer         (peripherals/)            final priority pixel mux → RGB
```

Not in the active top-level design (cleanup candidates): `multi_object_runtime.v`
is the legacy base pool superseded by the trigger/collider variants;
`player_properties_controller.v` and `character_object_holder.v` are empty stubs.

The three "mother" runtimes are `player_position_controller`, `game_runtime`, and
`game_ui_runtime`. Each owns a clean slice of state; everything else is a
"no-thought" executor that only reacts.

> For the full per-module breakdown and how the cores communicate, see
> [`hardware-architecture.md`](hardware-architecture.md).

---

## 6. Clock domains

All clocks derive from the 100 MHz input via `clk_div`, which toggles its output
every `DIV_FACTOR/2` input cycles (so output freq = `100 MHz / DIV_FACTOR`). The
divisor `localparam`s live at the top of `topModule.v`.

| Clock                | `topModule` divisor          | Frequency | Drives                                |
| -------------------- | ---------------------------- | --------- | ------------------------------------- |
| `clk_vga`            | `CLK_DIV_FACTOR_VGA = 4`     | **25 MHz**| `vga_translator` (pixel timing)       |
| `clk_player_control` | `..._PLAYER_CONTROL = 1_000_000` | **100 Hz** | player input, physics, movement   |
| `clk_object_control` | `..._OBJECT_CONTROL = 1_000_000` | **100 Hz** | object movement stepping           |
| `clk_centi_second`   | `..._CENTI_SECOND = 1_000_000`   | **100 Hz** | `wait_time` / `destroy_time` counters |
| `clk_calculation`    | `..._CALCULATION = 100_000`  | **1 kHz** | sync, collision, ROM index updates    |

`clk_calculation` is the highest-priority logic clock (after VGA): all state
transitions settle here before the slower 100 Hz behavior clocks consume them.
Each `..._SIM` variant (e.g. `CLK_DIV_FACTOR_CALCULATION_SIM = 5`) is used when
`IS_SIM=1` so waveforms are short.

> ⚠️ **Doc-drift flag.** The top-level README narrates `clk_centi_second` as
> 1 kHz ("we treat centi-second as millisecond"). The *committed* divisor is
> `1_000_000`, which is **100 Hz**. The 1 kHz clock in this design is
> `clk_calculation`. Reconcile the README to match the code (or change the
> divisor if 1 kHz timing was actually intended).

A synchronous-reset hold (`WAIT_TIME_FOR_CLK_SYNC = 100_000_000`, ≈1 s at
100 MHz) keeps `sync_reset` asserted long enough for every domain to come up
cleanly before gameplay starts.

---

## 7. Sync / update handshake

All parent↔child data transfer uses a two-wire protocol, evaluated in the
`clk_calculation` (1 kHz) domain, so it is safe across the slower clock domains.

| Signal     | Direction      | Polarity     | Meaning                              |
| ---------- | -------------- | ------------ | ------------------------------------ |
| `sync_*`   | parent → child | **active-low** (`0` = request) | "load data / start task" |
| `update_*` | child → parent | **active-high** (`1` = done)   | "task complete, output stable" |

Lifecycle: idle (`sync=1, update=0`) → parent drives data and asserts `sync=0` →
child latches and works → child asserts `update=1` → parent reads result and
releases `sync=1` → child clears `update=0`. This guarantees **≥3
`clk_calculation` cycles** per transaction and verifiable completion on both
sides. You can see it concretely in `attack_object_rom_reader.v` (the
`sync_attack_time` / `update_attack_time` pair) and in
`multi_object_trigger_runtime.v` (the per-object `sync_object_position_i[]` /
`update_object_position_i[]` arrays).

---

## 8. Data path: ROM → runtime → pixels

### 8.1 The `./mem` folder is the Python↔Vivado handoff

The repo has **three** top-level folders that meet here, and keeping them straight
is the single most common source of "it builds but the screen is wrong":

```
ChronoForge-FPGA-Engine/
├── mem/        ← the 6 compiled .mem ROMs            (Python WRITES, Vivado READS)
├── verilog/    ← the RTL source (.v)                 (the hardware logic)
└── vivado/     ← the Vivado project (ChronoForge.xpr)(synthesis/bitstream)
```

`mem/` is **not** inside `vivado/` and **not** inside `verilog/`. It is a neutral
hand-off directory:

- The Python toolchain writes `mem/*.mem` (see `compile_stage_to_mem.py`, which
  targets `project_root/mem`).
- The Verilog ROM readers in `verilog/sources/rom_reader/` load those files at
  reset.
- Vivado must be told that `mem/` is a source location, or it will never find the
  files (see [§8.3](#83-the-rom-path-wrong-problem-read-this)).

This separation is deliberate: you can regenerate game content (`mem/`) without
touching hardware logic (`verilog/`) or the project (`vivado/`).

### 8.2 How a ROM is loaded and unpacked

Each ROM reader declares a BRAM array and fills it from its `.mem` file at reset.
Note the filename is a **bare relative name** — no folder, no `./mem/` prefix:

```verilog
reg [71:0] rom [0:(1<<ADDR_WIDTH)-1];
always @(posedge clk) begin
    if (reset) $readmemh("attack_object.mem", rom);   // hex load
    ...
```

The reader then index-fetches one row and **un-scales** the packed fields — pixel
fields were stored as `value/4` by the Python compiler, so the reader shifts left
by 2 (`<< 2`) to restore full pixels:

```verilog
pos_x <= rom[addr][56:49] << 2;   // restore /4 scaling done at compile time
```

ROM map. The bit layout is owned by the Python encoder
`tools/compiler/json_encoders.py`; the reader bit-slices must stay in lock-step
with it (change one, change the other):

| `.mem` file            | Reader module                  | Row width | Load        | Feeds                |
| ---------------------- | ------------------------------ | --------- | ----------- | -------------------- |
| `game_manager.mem`     | `game_manager_rom`             | 72 bits   | `$readmemh` | Stage (global epoch) |
| `attack_object.mem`    | `attack_object_rom`            | 72 bits   | `$readmemh` | Attack timeline      |
| `platform_object.mem`  | `platform_object_rom`          | 64 bits   | `$readmemh` | Platform timeline    |
| `game_ui.mem`          | `game_ui_rom_reader`           | 88 bits   | `$readmemh` | Stage-UI timeline    |
| `character_object.mem` | `character_object_rom_reader`  | 24 bits   | `$readmemh` | Character timeline   |
| `font_data.mem`        | `font_data_rom_reader`         | 17-bit rows | **`$readmemb`** | glyph pixels    |

> ⚠️ `font_data.mem` is **binary** (`$readmemb`), not hex. If you ever regenerate
> it (`systhesis/gen_font_mem.py`), keep it in 0/1 text form — a hex file here
> renders garbled glyphs.

`game_manager.mem` and `game_ui.mem` carry an all-ones EOF closer row; the readers
detect it as `is_end` via `&rom[addr]` (reduction-AND = all bits set), which the
runtimes use to loop the game / UI back to index 0.

### 8.3 The "ROM path wrong" problem (read this)

Because `$readmemh`/`$readmemb` use a **bare filename**, the tool has to locate the
file on its own search path. Vivado searches the files that belong to the active
*fileset* (and the run directory). If `mem/` was never added to the project — or
you cloned/moved the repo and the stored paths broke — the file isn't found.

**Symptoms**
- Synthesis/elaboration warning like
  `WARNING: [Synth 8-xxxx] cannot find file 'attack_object.mem'` or
  `[Simtcl ...] file ... not found`.
- ROM contents come up all-`X` (simulation) or all-zero (hardware): black screen,
  no objects, player frozen, or garbage tiles — even though the build "succeeded."

**Fix (one-time, per project)**
1. In Vivado: **Add Sources → Add or create design sources** (or *Add files*),
   point at the repo's `mem/` folder, and add all six `.mem` files. Leave
   **"Copy sources into project" unchecked** so Vivado references the real
   `mem/` files the Python compiler overwrites (otherwise you'll be editing a
   stale copy inside `vivado/`).
2. For **simulation**, make sure the sim run's working directory can also resolve
   the files (adding them to the project sim fileset, or copying the six `.mem`
   into the sim run dir, both work).
3. Re-run **Synthesis** (and re-`$readmemh` happens on the next reset on hardware).

In the *current* repo the six files are already registered in
`vivado/ChronoForge.xpr`, so a fresh checkout on the same machine works as-is. The
steps above are what you do when porting the project to a new machine, a new
Vivado version, or after relocating `mem/`.

> Rule of thumb: **never** hard-code an absolute path into `$readmemh`. Keep the
> bare filename and fix it at the *project* level so Python can keep overwriting
> `mem/` freely.

---

## 9. Rendering pipeline

VGA timing comes from `vga_translator.v` (industry-standard 640×480@60:
`H_TOTAL=800`, `V_TOTAL=525`, sync active-low), which emits the current pixel
`x`, `y` and a `blank` flag.

The 25 MHz pixel clock against the 100 MHz core leaves only **~4 core cycles per
pixel**. That budget is too tight for deep mux trees, so per-object visibility is
combined with **bitwise-OR composition**, then a single fixed-priority mux picks
the color. In each `multi_object_*_runtime`:

```verilog
assign object_signal = |object_signal_i;   // OR of every instanced object's pixel hit
```

`universal_renderer.v` is the final stage — a purely combinational priority mux.
Highest priority wins; there are 8 visible layers plus blanking:

| Priority | Layer                 | Color (R,G,B / 4-bit) |
| -------- | --------------------- | --------------------- |
| (gate)   | VGA blank             | black                 |
| 1        | object collider       | neon cyan `0,14,14`   |
| 2        | object trigger        | neon red `15,3,3`     |
| 3        | game display border   | soft white `10,10,10` |
| 4        | player                | cool blue `2,6,15`    |
| 5        | HP-bar border         | `12,12,12`            |
| 6        | HP-bar fill           | red `14,4,4`          |
| 7        | character (text)      | light gray `12,12,12` |
| 8        | background            | dark gray `1,1,1`     |

Objects outside the play area can be suppressed: a pixel is dropped when
`out_side_display_signal` is set unless `transparent_out_screen_display` is
enabled for that UI stage (a resource/clarity trade-off chosen per stage UI).

---

## 10. Object autonomy & movement

Every attack/platform object is an independent `object_position_controller`
instance (`verilog/sources/object/object_position_controller.v`), created in a
`generate` loop inside its runtime. Each instance:

- **Sub-pixel precision:** positions are kept in "hired" registers scaled up by
  `SCALE_FACTOR = 8` (3 extra fractional bits), then shifted back down for
  rendering. This lets `speed` values move objects at fractional pixels/step.
- **8-way movement** (`movement_direction` 0–7: up, up-right, right, down-right,
  down, down-left, left, up-left), stepped on `obj_control_pulse` — a clean
  edge-detect of `clk_object_control` sampled into the `clk_calculation` domain.
- **Lifetime / destroy:** counts `destroy_time` down in its own centi-second
  counter and self-frees. `object_destroy_trigger` (as implemented in the RTL):

  | `destroy_trigger` | Behavior (from `object_position_controller.v`)            |
  | ----------------- | --------------------------------------------------------- |
  | `0`               | timer only — destroy when `destroy_time` reaches 0        |
  | `1`               | destroy when the object leaves the **display area** bounds |
  | `2`               | destroy when the object leaves the **screen** (640×480)   |

  > The README's `destroy_trigger` description differs from this; the table above
  > reflects what the hardware actually does. Worth aligning the docs.

Collision/trigger detection is a `for`-loop AABB overlap check against the player,
run at 1 kHz (`clk_calculation`). In `multi_object_trigger_runtime.v` a hit sets
`is_trigger_player`, which the UI runtime uses to subtract HP; HP reaching zero
asserts `is_player_dead` up to `game_runtime` for a global reset.
`multi_object_collider_runtime` instead feeds the nearest collider back to the
player as a movement boundary.

---

## 11. Player & physics

Player and physics constants are `localparam`s in `topModule.v` (Player
Controller Section). Defaults:

| Parameter            | Value | Meaning                                  |
| -------------------- | ----- | ---------------------------------------- |
| `INIT_PLAYER_POS_X`  | 316   | spawn X (px)                             |
| `INIT_PLAYER_POS_y`  | 314   | spawn Y (px)                             |
| `INIT_PLAYER_W`      | 17    | hitbox / sprite width                    |
| `INIT_PLAYER_H`      | 17    | hitbox / sprite height                   |
| `HORIZONTAL_SPEED`   | 15    | left/right speed                         |
| `VERTICAL_SPEED`     | 22    | jump/vertical impulse (1/16 scale)       |
| `GRAVITY`            | 8     | gravity accel (1/16 scale)               |
| `MAX_FALLING_SPEED`  | 35    | terminal fall speed (1/16 scale)         |
| `JUMP_H`             | 80    | jump height budget                       |

Gravity is enabled per stage by `gravity_direction` from the game-manager ROM
(0 = none). The player runs in the dedicated `clk_player_control` (100 Hz) domain
for deterministic feel independent of object count.

---

## 12. Configuration reference

All four config surfaces below are **compile-time** — after editing any of them
you must re-run synthesis → implementation → bitstream.

### 12.1 Pin mapping (`.xdc`)

File: `verilog/constrains/constains.xdc`. To port to a different board, change the
`PACKAGE_PIN` values (and `IOSTANDARD` if needed) for the ports in [§3](#3-top-module-io--pin-map),
and update `create_clock -period` if your oscillator isn't 100 MHz (a different
input frequency also means revisiting the dividers in [§12.3](#123-clock-dividers)).
The Verilog logic itself does not change.

### 12.2 Resource allocation (how many objects exist in hardware)

In `topModule.v`. **Two different kinds of constant** are easy to confuse:

| `localparam`                      | Value | What it is                                          |
| --------------------------------- | ----- | --------------------------------------------------- |
| `MAXIMUM_TRIGGER_OBJECT_AMOUT`    | 56    | **count of instanced attack objects** (parallel HW) |
| `MAXIMUM_COLLIDER_OBJECT_AMOUT`   | 25    | **count of instanced platform objects** (parallel HW) |
| `MAXIMUM_UI`                      | 20    | UI/character address bit-width (`game_ui_runtime`)  |
| `MAXIMUM_ATTACK_OBJECT`           | 20    | attack ROM **address bit-width** (≠ object count)   |
| `MAXIMUM_PLATFORM_OBJECT`         | 20    | platform ROM **address bit-width**                  |
| `MAXIMUM_STAGE`                   | 8     | stage index bit-width (→ up to 256 stages)          |
| `MAXIMUM_TIMES`                   | 30    | time counter bit-width                              |
| `INITIAL_STAGE` / `LAST_STAGE`    | 0 / 6 | stage loop bounds                                   |

The two `*_AMOUT` params (note the real spelling — missing `N`) directly set how
many `object_position_controller`/`object_renderer` instances synthesize, and thus
dominate LUT/FF usage. Raising them = more simultaneous objects + more area.

> The README's "How to Configs" section lists `MAXIMUM_..._AMOUNT` and a
> `MAXIMUM_CHARACTER_AMOUNT` that don't exist under those names. Use the names in
> this table.

### 12.3 Clock dividers

In `topModule.v`, the `CLK_DIV_FACTOR_*` constants from [§6](#6-clock-domains).
Output frequency = `100 MHz / factor`. Constraints to respect:

- `clk_vga`: must yield ≤ 25 MHz for 640×480@60 (factor 4 → exactly 25 MHz).
- `clk_calculation`: keep it the **fastest** derived clock (after VGA) so all
  handshakes settle before the behavior clocks sample.
- The `*_SIM` variants only matter when `IS_SIM=1`.

### 12.4 Play-area & display geometry

In `topModule.v` (Game Display Section): `GAME_DISPLAY_X0/Y0/X1/Y1` (default
`130/251/506/391`) and `GAME_DISPLAY_BORDER` (5). These set the on-screen play
box drawn by `game_display_renderer`. Per-stage display bounds also come from the
game-manager ROM (`display_pos_*`), so this is the hardware default/border.

---

## 13. Vivado build flow

After editing RTL/params, or after regenerating `.mem` files from the Python
toolchain:

1. **(content only)** Recompile ROMs: `python tools/main/compile_stage_to_mem.py`
   → overwrites `mem/*.mem`.
2. **Synthesis** — RTL → netlist. Resolve any unconnected-port / width warnings.
3. **Implementation** (place & route) — fix timing violations if reported.
4. **Generate Bitstream** — produces the `.bit`.
5. **Hardware Manager → Program Device** — Basys3 over USB; it runs immediately.

Because the `.mem` files are project sources, changing only game content means you
can skip straight to step 4 (Vivado re-reads the ROMs during bitstream gen).

---

## 14. Simulation

Testbenches live in `verilog/simulation/`:

| File                                | Purpose                                  |
| ----------------------------------- | ---------------------------------------- |
| `topSim.v` / `TopSim_defualt.v`     | top-level simulation wrappers            |
| `Topsim_Collider_pipline_test.v`    | collider pipeline focused test           |
| `test_bench.v`                      | general bench                            |

Drive `topModule` with `IS_SIM=1` so the clock dividers use their small `_SIM`
factors (e.g. calculation factor 5 instead of 100_000) and the reset-hold uses
`WAIT_TIME_FOR_CLK_SYNC_SIM`. Otherwise a single frame would take billions of
simulated cycles. Make sure the simulator's working directory can resolve the
`.mem` files referenced by `$readmemh`.

---

## 15. Resource utilization

Reported Basys3 utilization for the shipped configuration (per the README's
synthesis results; re-confirm against your own implementation report after any
change to the `*_AMOUT` params):

| Resource | Used  | Available | %    |
| -------- | ----- | --------- | ---- |
| LUT      | 18015 | 20800     | 87%  |
| FF       | 7196  | 41600     | 17%  |
| BUFG     | 6     | 32        | 19%  |

LUT is the binding constraint — driven mostly by the parallel object instances
([§12.2](#122-resource-allocation-how-many-objects-exist-in-hardware)) and the
100%-combinational renderers. BRAM holds the ROMs (Basys3 ≈ 1.8 Mb / 225 KB).

---

## 16. Known quirks & cleanup backlog

Documented honestly so the next person (you) isn't surprised. **Not fixed here —
this guide is docs-only.**

- **`clk_centi_second` is 100 Hz in code, but narrated as 1 kHz** in the README.
  Decide which is intended and make code + docs agree ([§6](#6-clock-domains)).
- **Misspelled but real paths:** `verilog/constrains/constains.xdc`,
  `systhesis/`, `interpret_langauge/`. Renaming touches the `.xpr`, Python
  imports, and `$readmemh` search paths — do it deliberately and re-test, not via
  blind find/replace.
- **Param typo `MAXIMUM_*_OBJECT_AMOUT`** (missing `N`). Harmless but worth a
  clean rename pass alongside the README fix.
- **Platform stage-transition logic is commented out** in
  `main_game_runtime.v` — intentional (attack timeline is the global epoch) but
  looks like dead code; add a comment or remove it.
- **Build artifacts are committed:** `vivado/.Xil/`, `vivado/*.zip`, and Python
  `__pycache__/`. Expand `.gitignore` and untrack them.
- The `destroy_trigger` and `gravity_direction` semantics in the README differ
  from the RTL ([§10](#10-object-autonomy--movement)); the tables here reflect the
  hardware.
