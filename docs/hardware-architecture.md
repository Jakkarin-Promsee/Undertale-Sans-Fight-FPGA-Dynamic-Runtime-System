# ChronoForge — Hardware Architecture

How the engine works *inside*: the design philosophy, every RTL module, and —
most importantly — how the runtime cores talk to each other.

This is the **reference** companion to [`hardware-guide.md`](hardware-guide.md).
The guide tells you how to *build and configure* the hardware; this document tells
you how it *thinks*. Everything below was traced from `verilog/sources/` — when a
detail here disagrees with the top-level `README.md`, the RTL is correct.

---

## Table of contents

1. [Design philosophy](#1-design-philosophy)
2. [System block diagram](#2-system-block-diagram)
3. [The three timelines](#3-the-three-timelines)
4. [Module catalog](#4-module-catalog)
   - [4.1 Clocking & VGA](#41-clocking--vga)
   - [4.2 ROM readers](#42-rom-readers)
   - [4.3 Runtime cores ("mother" modules)](#43-runtime-cores-mother-modules)
   - [4.4 Per-object executors](#44-per-object-executors)
   - [4.5 Player](#45-player)
   - [4.6 Display & compositor](#46-display--compositor)
   - [4.7 Stubs & legacy](#47-stubs--legacy)
5. [Communication between runtime cores](#5-communication-between-runtime-cores)
6. [Handshake protocols in detail](#6-handshake-protocols-in-detail)
7. [End-to-end walkthroughs](#7-end-to-end-walkthroughs)
8. [Clock-domain crossing](#8-clock-domain-crossing)
9. [Signal glossary](#9-signal-glossary)

---

## 1. Design philosophy

### 1.1 Why a pure-hardware engine?

ChronoForge replaces the usual "CPU runs a game loop" model with **independent
hardware processors**, each owning one job and one clock domain. There is no
instruction stream, no script interpreter, and no central scheduler — it is a
**Direct-Logic Engine** where every game event is a hardware state transition.
The goal throughout is maximum efficiency on a low-end board: lowest LUT/FF cost
per behavior, fastest possible pipeline.

What that model buys you:

- **Zero-instruction overhead.** A CPU fetches → decodes → executes one
  instruction at a time. ChronoForge has no fetch/decode step at all; logic reacts
  directly to ROM data, eliminating the sequential-execution bottleneck.
- **Decentralized processing.** Each module has one specific duty. Avoiding a
  single master controller makes the event-driven strategy both faster and more
  resource-efficient.
- **Massive parallelism.** Every object — trigger, collider, character — is its
  own hardware instance (`generate` loops), so they all compute at once. Frame
  cost stays flat regardless of object density, holding 640×480 @ 60 Hz.
- **Hardware-level determinism.** With no OS and no interrupts, every frame is
  computed identically given the same ROM and inputs. What the compiler emits is
  exactly what the silicon executes, every time.
- **The performance peak.** Within the ~4-clock-per-pixel VGA budget (and without
  spatial partitioning), the engine composes pixels for its full default pool —
  56 triggers, 25 colliders, 79 characters — in ≈18k LUTs / 7k FFs, and can
  address tens of thousands of object records in BRAM (≈225 KB on Basys3).

The cost of this model is **communication complexity**: independent cores that run
on different clocks must hand data to each other safely. ChronoForge solves that
with one small handshake idiom, reused everywhere
([§6](#6-handshake-protocols-in-detail)).

### 1.2 The three mother cores

All decision-making lives in three "mother" cores; everything else is a
"no-thought" executor that only renders or moves when signaled:

1. **`player_position_controller`** — the player entity (input, physics, collision).
2. **`game_runtime`** — all non-player gameplay objects + the stage timeline.
3. **`game_ui_runtime`** — UI, HUD, HP, and visual-only character entities.

Each owns a clean slice of state and a clock domain. Gameplay itself is
pre-compiled into `.mem` ROMs where **each row is one event** — timelines advance
by reading rows ([§3](#3-the-three-timelines)), not by branching logic.

---

## 2. System block diagram

Top level is `topModule.v`. Solid arrows = data/signal flow; the three mother
cores are marked `★`.

```
                         100 MHz clk ──► clk_div ×5 ──► clk_vga / player / object / centi / calculation
                                                            │
                              ┌─────────────────────────────┴───────────────────────────────┐
                              ▼                                                               ▼
                        vga_translator ── x, y, blank ───────────────────────────────► (every renderer)

   ROM (.mem in BRAM)        RUNTIME CORES                         EXECUTORS / RENDER
   ─────────────────        ─────────────                         ──────────────────
   game_manager_rom ◄──────► ★ game_runtime ──┐ display_pos_*      game_display_controller ─► game_display_renderer
   attack_object_rom ◄─────► (stage timeline) │ gravity_dir
   platform_object_rom ◄────►                 │ is_reset_stage
            │                                 │ current_time
            │ data bus + sync_*_position      ▼
            ├──────────────► multi_object_trigger_runtime  ──► is_trigger_player ─┐
            │                  └ object_position_controller[] + object_renderer[] │
            ├──────────────► multi_object_collider_runtime ──► ground feedback ─┐ │
            │                  └ object_position_controller[] + object_renderer[]│ │
            │                                                                    │ │
   game_ui_rom_reader ◄────► ★ game_ui_runtime  ◄── is_trigger_player ◄──────────┘ │
   character_obj_reader ◄──►  (UI/char timeline) ── is_player_dead ──► game_runtime │
   font_data_rom_reader ────►                                                       │
                                                                                    │
   switches ──► ★ player_position_controller ◄── ground feedback ◄─────────────────┘
                       └ player_renderer

   ALL pixel signals ──► universal_renderer ──► RED / GREEN / BLUE (4 bits each)
```

---

## 3. The three timelines

Gameplay is three independent **ROM index counters**, each advancing when its
current object's `wait_time` elapses (measured against the shared `current_time`):

| Timeline      | Index reg     | Driven by                       | ROM(s)                                |
| ------------- | ------------- | ------------------------------- | ------------------------------------- |
| **Attack**    | `attack_i`    | `game_runtime`                  | `attack_object.mem`                   |
| **Platform**  | `platform_i`  | `game_runtime`                  | `platform_object.mem`                 |
| **Character** | `character_i` | `game_ui_runtime`               | `character_object.mem` (+ font)       |

### 3.1 The hardware timeline scheduler

Each timeline walks its own ROM object list from index `0` to the terminal EOF
header (`0xFFF…`). Every object carries both **spatial data** (position, size,
direction, speed) and **temporal data** (`wait_time`, `destroy_time`). Each
timeline has its own internal wait counter: the current object becomes active only
when that counter reaches zero, after which the index advances to the next ROM
row. The whole scheduler is just this loop, in hardware, per timeline:

```
Runtime Counter → wait Gate → Object Index → ROM → add wait → Runtime Counter
```

Because each timeline advances independently, objects overlap, interleave, and run
concurrently with **no branching, no script engine, and no CPU control logic**:

```
Attack:    start ──► A0 ──► A1 ───────────► A2 ─► end ─► reset
Platform:  start ─► P0 ───────────► P1 ──► P2 ─► end
Character: start ─► C1 ─► C2 ──────────────► C3 ─► end
```

A **null object** (`w=0, h=0`) draws nothing but still consumes its `wait_time`,
so an empty attack becomes a pure time delay — that's how pauses, waves, and
pacing are scripted directly in ROM. The number of active objects per timeline is
set by a dynamic register system, configurable per game, per board, and per
resource budget ([guide §12.2](hardware-guide.md#122-resource-allocation-how-many-objects-exist-in-hardware)).

### 3.2 Wrapper timelines

Two "wrapper" timelines sit above them, advanced when their inner objects finish:

- **Stage** (`current_stage`, in `game_runtime`) wraps Attack + Platform +
  per-stage config (`game_manager.mem`).
- **Stage-UI** (`addr` in `game_ui_runtime`) wraps Character + HP/UI config
  (`game_ui.mem`).

**The Attack timeline is the global epoch.** In `main_game_runtime.v`, a stage
advances only when the **attack** count for that stage is exhausted (the platform
end-branch is commented out). When the stage timeline reaches the all-ones EOF
row (`is_end`), or the player dies, `game_runtime` snaps `current_stage` back to 0
and asserts `is_reset_stage`, restarting the whole game.

---

## 4. Module catalog

23 modules in `verilog/sources/`. Each entry lists its clock, role, and the one or
two behaviors worth knowing.

### 4.1 Clocking & VGA

**`clk_div`** (`top/clk_div.v`) — parameterized divider. Toggles its output every
`DIV_FACTOR/2` input cycles, so `f_out = 100 MHz / DIV_FACTOR`. Five instances
create the clock tree ([guide §6](hardware-guide.md#6-clock-domains)).

**`vga_translator`** (`peripherals/vga_translator.v`) — `clk_vga` (25 MHz).
Standard 640×480@60 sweep (`H_TOTAL=800`, `V_TOTAL=525`). Emits the active pixel
coordinate `x,y` (10-bit), active-low `HS`/`VS`, and `blank` (1 outside the
visible area). Every renderer keys off this `x,y`.

### 4.2 ROM readers

All six live in `rom_reader/` and share a pattern: declare a BRAM array sized to
the row width, `$readmem*` it on reset, then a tiny 2-step FSM (`update_data`
latches the row, next cycle raises the `update_*` "done" flag). Pixel fields are
restored with `<< 2` (compiler stored them `/4`). EOF is detected with `&rom[addr]`
(reduction-AND ⇒ all bits 1).

| Module                         | Row    | Load        | Notable outputs                                       |
| ------------------------------ | ------ | ----------- | ----------------------------------------------------- |
| `game_manager_rom`             | 72-bit | `$readmemh` | stage, attack/platform_amount, gravity, display box, `is_end` |
| `attack_object_rom`            | 72-bit | `$readmemh` | type, colider_type, dir, speed, pos/size, destroy, `next_attack_time` |
| `platform_object_rom`          | 64-bit | `$readmemh` | dir, speed, pos/size, destroy, `next_platform_time`   |
| `game_ui_rom_reader`           | 88-bit | `$readmemh` | HP config, bar geometry, sensitivity, `is_end`        |
| `character_object_rom_reader`  | 24-bit | `$readmemh` | character_pos_x/y, character_index                    |
| `font_data_rom_reader`         | 17-bit rows | **`$readmemb`** | **combinational** glyph lookup (no clock)      |

`font_data_rom_reader` is special: it's purely combinational. Given a `char_index`
and local `x,y` (0–16), `row_addr = char_index*17 + y` and the output bit is
`rom[row_addr][16 - x]` (MSB-left). This is the bitmap font sampler used by the UI.

### 4.3 Runtime cores ("mother" modules)

**`game_runtime`** (`runtime/main_game_runtime.v`) — `clk_calculation` (logic) +
`clk_centi_second` (time). The stage brain. Holds `current_stage`, `attack_i`,
`platform_i`, and the shared `current_time` counter. A two-state FSM:

- *Spawning* (`sync_game_manager=1`): when `current_time ≥ next_attack_time`, it
  advances `attack_i` and requests the next time from the attack ROM via the time
  handshake; same for platforms. When the stage's `attack_amount` is reached it
  bumps `current_stage` and drops to…
- *Waiting* (`sync_game_manager=0`): holds until the game-manager ROM is ready and
  the inter-stage `wait_time` elapses, then re-enters Spawning.

On `is_end` or `is_player_dead`, it resets to stage 0 and pulses `is_reset_stage`.

**`game_ui_runtime`** (`runtime/game_ui_runtime.v`) — `clk_calculation`,
`clk_centi_second`, `clk_vga`. The UI/HUD brain. It:
- walks the Stage-UI timeline (`addr`) and the Character timeline (`character_i`);
- maintains an array of up to `CHARACTER_AMOUNT` (default **79**) character slots,
  each with position + glyph index, written from ROM (story text) and/or
  auto-generated (the live `HP ###/###` readout, slots 0–8, in 2- or 3-digit mode);
- computes the HP bar fill width (`healt_current_hires * healt_bar_w / healt_max`)
  and its border;
- decrements HP when `is_trigger_player` is asserted, gated by a
  `healt_bar_sensitivity` countdown (i-frames);
- raises `is_player_dead` (= `reset_when_dead`) when HP hits 0.
A combinational loop over all character slots picks the glyph hit for the current
pixel and feeds `font_data_rom_reader` → `character_signal`.

**`multi_object_trigger_runtime`** (`runtime/`) — manages the live pool of attack
(trigger) objects. Hosts a `generate` array of `OBJECT_AMOUNT`
`object_position_controller` + `object_renderer` pairs. Three jobs:
1. **Slot allocation**: keeps `object_ready_state[]` (free-slot bitmap); on a spawn
   request from the attack ROM it finds a free slot, hands it the object data, and
   acks the ROM. Freed objects (`object_free_i`) return to the pool.
2. **Player damage**: a `for`-loop AABB test of the player box against every live
   object → `is_trigger_player`.
3. **Pixels**: `object_signal = |object_signal_i` (bitwise-OR of all instances).

**`multi_object_collider_runtime`** (`runtime/`) — identical structure for platform
(collider) objects, but instead of damage it computes **ground feedback**: a
`for`-loop finds the highest object directly under the player and outputs
`collider_ground_h_player` + `is_collider_ground_player` for the player physics.

### 4.4 Per-object executors

**`object_position_controller`** (`object/object_position_controller.v`) —
`clk_calculation` + `clk_object_control` + `clk_centi_second`. One instance per
live object; this is the "State-Driven Autonomy" unit. On spawn it latches
position/direction/speed/size into **sub-pixel "hired" registers** (scaled ×8 via
`SCALE_FACTOR_BITS=3`). Each `obj_control_pulse` (an edge-detected
`clk_object_control` tick) it steps the position in one of 8 directions. It runs
its own `destroy_time` countdown (in its private centi-second counter) and frees
itself (`object_free`) on timeout or when its `destroy_trigger` bound is crossed:

| `destroy_trigger` | frees when…                              |
| ----------------- | ---------------------------------------- |
| `0`               | `destroy_time` reaches 0                  |
| `1`               | object leaves the **display area** box    |
| `2`               | object leaves the **screen** (640×480)    |

**`object_renderer`** (`object/object_renderer.v`) — pure combinational AABB test:
`render = (x,y) inside (pos, pos+w/h)`. One per object; outputs are OR-reduced by
the parent runtime.

### 4.5 Player

**`player_position_controller`** (`player/`) — `clk_player_control` (100 Hz). The
player brain. Sub-pixel positions (×16, `SCALE_FACTOR_BITS=4`). Implements:
- 4-button movement clamped to the display box;
- a staged-acceleration gravity model (`falling_speed` ramps in bands up to
  `MAX_FALLING_SPEED`) gated by `gravity_direction`;
- jump with hold/height limit (`JUMP_H`);
- landing on either the screen floor **or** a collider object, using
  `is_collider_ground_player` / `collider_ground_h_player` from the collider
  runtime.

Outputs `player_pos_x/y/w/h` consumed by both object runtimes (for collision) and
`player_renderer`.

**`player_renderer`** (`player/`) — combinational AABB → `player_render` pixel.

### 4.6 Display & compositor

**`game_display_controller`** (`game_display/`) — `clk_object_control`. Selects the
active play-area rectangle: the per-stage `display_pos_*` from the game-manager
ROM (or the `GAME_DISPLAY_*` defaults on reset). Outputs `game_display_x0..y1`.

**`game_display_renderer`** (`game_display/`) — combinational. Draws the play-area
**border** (`render`) and exports `out_side_display_signal` (1 when the pixel is
outside the play box), used to optionally hide off-area objects.

**`universal_renderer`** (`peripherals/`) — combinational fixed-priority mux. Takes
every layer's pixel signal and outputs the winning color
([guide §9](hardware-guide.md#9-rendering-pipeline) has the full priority/color
table). This is the only module that drives `RED/GREEN/BLUE`.

### 4.7 Stubs & legacy

These exist in the tree but are **not** part of the active top-level design — good
candidates for the cleanup pass:

- **`multi_object_runtime`** (`runtime/`) — the original base version of the
  multi-object pool, *without* player feedback. Superseded by the trigger/collider
  specializations that `topModule` actually instantiates.
- **`player_properties_controller`** (`player/`) — empty stub (1 line).
- **`character_object_holder`** (`rom_reader/`) — empty stub (1 line).

---

## 5. Communication between runtime cores

This is the heart of the design. Six conversations connect the cores; each uses
either a **handshake** (for cross-clock data transfer) or a **direct wire** (for a
continuously-valid status).

```
                 ┌───────────────── time handshake ─────────────────┐
                 │  sync_*_time / update_*_time + addr + current_time │
   game_manager_rom ◄──► game_runtime ◄──► attack_object_rom / platform_object_rom
                 └──────────────────────────────────────────────────┘
                                  │ (data bus + sync_*_position)
                                  ▼
        ┌───────── position handshake ──────────┐
        │ sync_*_position / update_object_position│
        ▼                                         ▼
   multi_object_trigger_runtime          multi_object_collider_runtime
        │  ▲                                   │  ▲
 is_trigger_player                       ground feedback (h + flag)
        │  │ player_pos_*                      │  │ player_pos_*
        ▼  │                                   ▼  │
   game_ui_runtime                        player_position_controller
        │
   is_player_dead  ───────────────────────────► game_runtime  ──► is_reset_stage (broadcast)
```

**The six conversations:**

| # | From → To                                   | Mechanism            | Signals                                                                 |
| - | ------------------------------------------- | -------------------- | ---------------------------------------------------------------------- |
| 1 | `game_runtime` ↔ attack/platform/manager ROM | time handshake       | `sync_*_time` / `update_*_time`, `addr` (`*_i`), `current_time`, `next_*_time` |
| 2 | ROM readers → object runtimes               | data bus + position handshake | `attack_*`/`platform_*` fields; `sync_*_position` / `update_object_*_position` |
| 3 | `player` → object runtimes                  | direct wires         | `player_pos_x/y/w/h`                                                   |
| 4 | `trigger runtime` → `game_ui_runtime`       | direct wire          | `is_trigger_player` (player hit → lose HP)                             |
| 5 | `collider runtime` → `player`               | direct wires         | `collider_ground_h_player`, `is_collider_ground_player`               |
| 6 | `game_ui_runtime` → `game_runtime` → all    | direct wire (status) | `is_player_dead` → `is_reset_stage` (broadcast to both object runtimes + UI) |

Cross-cutting buses also fan out from `game_runtime`: `display_pos_*` →
`game_display_controller` and both object runtimes; `gravity_direction` → player;
`current_time` → ROM readers and UI; `is_reset_stage` → both object runtimes + UI
(flushes all live objects on a game reset).

Notice the **damage loop is a full cycle across three cores**:
`player → trigger runtime (is_trigger_player) → game_ui_runtime (HP--) →
is_player_dead → game_runtime (reset) → is_reset_stage → everyone`. And the
**physics loop** is a 2-core cycle: `player → collider runtime (find ground) →
collider_ground_* → player`.

---

## 6. Handshake protocols in detail

Every cross-clock transfer uses the same two-wire idiom, evaluated in
`clk_calculation` (1 kHz):

- `sync_*` — **parent → child**, **active-low**. `0` = "load this / start".
- `update_*` — **child → parent**, **active-high**. `1` = "done, output stable".

Idle is `sync=1, update=0`. The exchange guarantees ≥3 `clk_calculation` cycles, so
both sides see a clean edge regardless of their own slower clocks.

There are three concrete instances of the idiom:

**(a) Time handshake — `game_runtime` ↔ object ROM** (advance a timeline):
1. `game_runtime` sets `addr=attack_i`, drops `sync_attack_time=0`.
2. The ROM reader latches the row, computes `next_attack_time = current_time +
   wait_time*10`, raises `update_attack_time=1`, and *also* drops
   `sync_attack_position=0` to ask the object pool to spawn this object.
3. `game_runtime` sees `update_attack_time`, re-raises `sync_attack_time=1`.

**(b) Position handshake — object ROM ↔ object runtime** (spawn into the pool):
1. ROM reader asserts `sync_*_position=0` with the object data on the bus.
2. The runtime allocates a free slot (`object_ready_state[]`), drives that slot's
   `sync_object_position_i[slot]=0`; the `object_position_controller` latches the
   data and raises `update_object_position_i[slot]`.
3. The runtime raises `update_object_position` back to the ROM reader, which
   re-arms `sync_*_position=1`. Slots auto-return to "ready" when their object
   self-frees (`object_free_i`).

**(c) Master sync — inside `object_position_controller` and `game_ui_runtime`**:
a smaller `sync_master`/`update_master` pair crosses from the logic domain
(`clk_calculation`) into the time domain (`clk_centi_second`) so destroy-timers and
HP counters start cleanly aligned with freshly loaded data.

---

## 7. End-to-end walkthroughs

**A. Spawning one attack object**
1. `game_runtime` time reaches `next_attack_time`; it advances `attack_i` and
   starts time-handshake (a) with `attack_object_rom`.
2. The ROM reader latches row `attack_i`, sets the next time, and starts
   position-handshake (b) toward `multi_object_trigger_runtime`.
3. The runtime finds a free slot and loads an `object_position_controller`, which
   begins autonomous movement on its `obj_control_pulse`.
4. Each frame, that object's `object_renderer` OR-contributes to
   `object_trigger_signal`; the AABB loop may raise `is_trigger_player`.

**B. Player takes a hit and dies**
1. Trigger runtime's AABB loop finds player∩object → `is_trigger_player=1`.
2. `game_ui_runtime` decrements `healt_current_hires` (rate-limited by
   `healt_bar_sensitivity`); the HP bar shrinks and the `HP ###/###` text updates.
3. At HP 0, `is_player_dead = reset_when_dead` is raised to `game_runtime`.
4. `game_runtime` resets `current_stage=0` and pulses `is_reset_stage`, which
   flushes every live object in both pools and resets the UI back to stage 0.

**C. Rendering one pixel** (every 25 MHz tick)
1. `vga_translator` produces `x,y,blank`.
2. All renderers (objects, player, display border, HP bar, characters) evaluate
   their AABB/font tests combinationally for this `x,y`.
3. `universal_renderer` applies fixed priority and drives `RED/GREEN/BLUE`.

---

## 8. Clock-domain crossing

The design runs five clocks but keeps CDC disciplined:

- **`clk_calculation` (1 kHz) is the synchronization hub.** All inter-core
  handshakes and the slot/iterator logic live here, so handoffs settle before the
  slower 100 Hz behavior clocks sample them.
- **Edge-detection across domains.** Where a 100 Hz behavior tick must drive logic
  in the 1 kHz domain (object movement), the controller double-registers the
  source clock and derives a one-cycle pulse:
  `obj_control_pulse = clk_obj_sync_1 & ~clk_obj_sync_2`. Movement happens only on
  that pulse, so a faster logic clock never double-steps an object.
- **Master-sync handoff** (protocol (c)) crosses logic→time domains for timers.
- **Reset hold.** `sync_reset` is held ~1 s after release
  (`WAIT_TIME_FOR_CLK_SYNC`) so every domain and `$readmem*` init completes before
  gameplay starts.

> The `clk_centi_second` vs `clk_calculation` naming is the one rough edge: the
> README narrates centi-second as 1 kHz, but the committed divider makes it 100 Hz
> (the 1 kHz clock is `clk_calculation`). See
> [guide §6](hardware-guide.md#6-clock-domains).

---

## 9. Signal glossary

| Signal                         | Meaning                                                        |
| ------------------------------ | ------------------------------------------------------------- |
| `current_time`                 | shared game clock (counts in `game_runtime`, `centi_second`)  |
| `current_stage` / `attack_i` / `platform_i` / `character_i` / `addr` | timeline index counters |
| `sync_*` / `update_*`          | handshake request (active-low) / done (active-high)           |
| `next_*_time`                  | timestamp at which a timeline may advance to its next object   |
| `is_trigger_player`            | a live attack object overlaps the player (damage)             |
| `is_collider_ground_player` / `collider_ground_h_player` | player is standing on a platform / its top Y |
| `is_player_dead`               | HP reached 0 and the UI stage opts into death-reset            |
| `is_reset_stage`               | global reset pulse; flushes objects and rewinds timelines      |
| `is_end`                       | EOF row (`&rom[addr]`) reached in a manager/UI ROM             |
| `object_free` / `object_ready_state[]` | per-object "I'm idle" / pool's free-slot bitmap       |
| `*_signal` / `render`          | per-layer pixel-hit going into `universal_renderer`           |
| `out_side_display_signal` / `transparent_out_screen_display` | pixel is outside play box / whether to still hide off-box objects |
| `blank`                        | VGA blanking (outside 640×480 visible area)                   |
| `*_hired` / `*_hires`          | sub-pixel position registers (object ×8, player ×16)          |
| `obj_control_pulse`            | one-cycle pulse marking a movement step (CDC edge-detect)     |
