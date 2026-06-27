# ChronoForge FPGA Engine

## Technical Specification & Architecture Document

**Project Goal:**

- Let anyone build games on an FPGA board without touching hardware code
- Using 4 switch to contron. Including up, down, left, and right.
- Push FPGA resource optimization to the limit of the board
- Build a custom runtime + binary format for max efficiency
- Study, test, and prove my hardware-runtime game engine idea

**Target Platform:** Xilinx Basys3 FPGA Board (Artix-7)
**Primary Application:** Deterministic 2D Game Engine (640x480 @ 60Hz)
**Current Architecture Version:** V4
**Date:** December 29, 2025

---

## Overview

ChronoForge started from a simple counter circuit, mapping indices into ROM for event-driven commands. Over time, it grew to handle the full requirements of a game — entirely designed and implemented by me: circuits, event command structure, compiler, and interpreter. We didn’t even check how others did it; this was our personal playground for experimenting with command counting and hardware behavior.

ChronoForge is a pure-hardware game runtime that runs entirely on an FPGA. **No CPU**. **No ISA**. **No OS**. **No emulator**. Just raw event-driven circuits executing your game logic directly from post-processed data stored as hex blocks.

Our goal is simple: maximum efficiency. That means **lowest LUT usage** and **lowest flip-flops** for each behavior, while maintaining **the fastest possible pipeline**.

### Why ChronoForge?

ChronoForge is a **Direct-Logic Engine** — no CPU, no instruction stream, no OS.
Every game event is a hardware state transition, so there is zero fetch/decode
overhead, every object runs on its own parallel pipeline (flat frame cost at
640×480 @ 60Hz), and every frame is fully deterministic. At its peak it composes
pixels for its whole object pool inside the ~4-clock VGA budget in ≈18k LUTs / 7k FFs.

> The full breakdown of these advantages — and exactly how the decentralized cores
> achieve them — lives in **[docs/hardware-architecture.md](docs/hardware-architecture.md)**.

Everything is designed to squeeze the absolute most out of the FPGA while staying easy to build. You can write your entire game using Python classes without ever touching a single line of Verilog.

<br>

<p align="center" style="text-align: center;">
    <a href="https://youtu.be/yzlUlyLRUwM">
        <img src="docs/images/chonoforge_showcase.png" width="800px" alt="Watch the ChronoForge FPGA Engine Showcase on YouTube">
    </a>
    <br>
    <a href="https://youtu.be/yzlUlyLRUwM">Watch the System Demo on YouTube</a>
</p>

---

## Key Concept — Hardware Timeline Scheduler

ChronoForge drives all gameplay through three independent hardware timelines —
**Attack**, **Platform**, and **Character** — each a ROM index counter that walks
its object list and advances when the current object's `wait_time` elapses (no CPU,
no script engine). The **Attack timeline is the global epoch**: when it reaches its
terminal header (`FFF*`) the whole game resets, so empty "null" objects double as
pure time delays for scripting pauses, waves, and pacing.

```bash
Attack:    start ------> A0 ------> A1 -------------> A2 -> end -> reset

Platform:  start --> P0 -------------> P1 -----> P2 --> end

Character: start ->  C1 ---> C2 ------------------> C3 --> end
```

> Full scheduler mechanism, per-module behavior, and how the cores communicate:
> **[docs/hardware-architecture.md](docs/hardware-architecture.md)**.

---

## What we do

- **Hardware Runtime Engine:**
  - Designed and built in Vivado + Verilog
  - Use four on boad button for input (up/down/left/right)
  - Uses five main runtime pipelines for game stage, game ui, and trigger/collider/character object
  - Reads data from ROM (.mem files in hex form)

  - Configurable resource allocation amount (defaults, set in `topModule.v`):
    - 56 dynamic trigger objects
    - 25 dynamic collider objects
    - 79 dynamic character objects

  - Configurable object pools:
    - Free-placed position
    - Custom size
    - 32 movement speed levels
    - 8 movement directions
    - Wait time
    - Destroy time

  - Configurable player pools:
    - Free-placed display position & size
    - Custom player hitbox size
    - Gravity enable/disable
    - HP & damage sensitivity
    - HP bar enable/disable & position

<br>

- **Compiler:**
  - Uses json to be Skeleton structure to store all data element for each runtime
  - Uses python script to compile json to mem file in hex form for hardware runtime stucture
  - All data will be preprocessing on compiler side seperate to 5 mem files that be able to use immediatelly on hardware side

<br>

- **Interpreter/Game engine:**
  - Uses python class to interpret each data type element (python class -> json -> hex)
    - Game Stage: `EntireGame`, `GameManager`, `GameStage`, `AttackObject`, and `PlatformObject`
    - Game Stage UI: `EntireGameUI`, `GameUIStage`, `GameUI`, and `CharacterObject`
  - Uses simple python lists + `for` loops so repeated objects (bullet patterns, platforms) can be generated programmatically
  - Has a python GUI to visualize all object positions before uploading to the board

  > Full authoring walkthrough and class reference: **[docs/python-guide.md](docs/python-guide.md)**

  <p align="center" style="text-align: center;">
      <img src="docs\images\chonoforge_python_gui2.png" alt="ChronoForge Python GUI" width="800px">
  </p>

---

## How much resource we takes

- **Current Board Utilization (Basys3):**

  | Resource | Utilization | Available | Board Usage % |
  | :------- | :---------- | :-------- | :------------ |
  | LUT      | 18015       | 20800     | 87%           |
  | FF       | 7196        | 41600     | 17%           |
  | BUFG     | 6           | 32        | 19%           |

  (Default: 56 dynamic attack, 25 dynamic platform, and 79 dynamic character)

<br>

- **ROM data capacity:**

  | ROM Type         | Bytes/Object | Maximum Count (Basys3 BRAM) |
  | :--------------- | :----------- | :-------------------------- |
  | Attack Object    | 9 bytes      | 25,000 attacks              |
  | Platform Object  | 8 bytes      | 28,125 platforms            |
  | Character Object | 3 bytes      | 75,000 characters           |

  (Basys3 BRAM capacity: 1.8 Mb ≈ 225 KB total)

---

## The Challenges

1. **The 4-Clock Pixel Deadline**
   Our main clock runs at 100 MHz, but the 25 MHz VGA clock (640x480 @ 60 Hz) leaves only **4 cycles per pixel** for processing. With a workload of 100 triggers, 50 colliders, and 100 characters, simple multiplexer chains or `if-else` logic are too slow. We initially considered **Spatial Partitioning**, but the hardware structure was too complex to link with our event-driven runtime. The fix was a "brutal" **Bitwise OR Composition**—all object pixel signals are merged instantly to ensure the fastest possible compute time.
   <br>

2. **Event-Driven Runtime Synchronization**
   The plan was to separate runtimes by responsibility and connect them via a bridge clock (`clk_calculation`). While simple in theory, it was brutal in practice because each runtime had its own "self-thought" and logic, leading to non-linear communication timelines. To fix this, we reduced redundancy by pulling all decision-making into **three main runtimes** and stripping the others down to "no-thought" executors that only react.
   <br>

3. **Instance Spawning Lag (The Millisecond Lie)**
   Testing on real hardware revealed that a 100 Hz timer (0.01s) wasn't enough. Our synchronization strategy requires three clock checks, adding up to a 0.03s delay that is noticeable to players. We increased the timer to **1 kHz**, meaning the signal `centi_second` now actually counts in **milliseconds**. We kept the name to avoid breaking the logic, but the behavior is now correct.
   <br>

4. **Compiler and Interpreter Layer**
   With no prior experience in this field, we had to figure out how to bridge human-readable code with post-processed hex data. The solution evolved into a **Meaning Stack**:  
   `Machine Code → JSON Decode → JSON Source → Python Class → Workspace Environment`.  
   Each layer adds intention while removing ambiguity, making it convenient for users to build games without touching hardware.
   <br>

5. **A Tangle Too Large to Visualize**
   The biggest challenge is that the project grew into a massive, tangled circuit through trial and error. Because we lacked experience, features were added until they worked, resulting in inconsistent naming rules and coding styles across modules. We refactor frequently, but parts of the system remain messy. This section exists to document that reality, not to hide it.
   <br>

---

## Project structure

```bash
ChronoForge-FPGA-Engine/
├── CLAUDE.md            ← Repo map for contributors / AI agents
├── README.md            ← This file (project overview)
├── docs/                ← Focused guides + image assets
│   ├── python-guide.md          ← Authoring + compiler
│   ├── hardware-guide.md        ← Vivado build & config
│   ├── hardware-architecture.md ← How the hardware works
│   └── images/
├── mem/                 ← Final compiled .mem ROM images loaded by the FPGA
├── systhesis/           ← Font tooling + 17×17 glyph images
├── tools/               ← Python toolchain
│   ├── main/            ← Game authoring workspace (you write here)
│   │   ├── stage/       ← Attack + platform objects per stage
│   │   ├── stage_ui/    ← UI config + on-screen character (text) objects
│   │   ├── compile_stage_to_json.py
│   │   ├── compile_stage_to_mem.py
│   │   └── open_game_engine_gui.py
│   ├── interpret_langauge/ ← Authoring class API (game_class.py)
│   ├── compiler/        ← Folding + bit-packing compiler
│   └── python_gui/      ← tkinter stage previewer
├── verilog/             ← All hardware source code
│   ├── constrains/      ← Pin mapping (constains.xdc)
│   ├── simulation/      ← Testbenches
│   └── sources/         ← RTL modules (top/, runtime/, rom_reader/, object/, …)
└── vivado/              ← Vivado project (ChronoForge.xpr)
```

---

## Documentation

| Guide | What's inside |
| ----- | ------------- |
| **[docs/python-guide.md](docs/python-guide.md)** | Authoring games in Python: the class API, writing stages/UI, procedural patterns, compiler internals, and font tooling. |
| **[docs/hardware-guide.md](docs/hardware-guide.md)** | Using the hardware: Vivado build flow, board/pin config, clock & resource knobs, and how the `.mem` ROMs wire into the project. |
| **[docs/hardware-architecture.md](docs/hardware-architecture.md)** | How the engine works inside: every module, the three timelines, and how the runtime cores communicate. |

(For contributors and AI agents, `CLAUDE.md` is a one-page map of the whole repo.)

---

## Quick start

**Author & compile a game (Python side):**

```bash
# 1. Python stage classes -> per-stage JSON
python tools/main/compile_stage_to_json.py

# 2. (optional) preview object layout & timing
python tools/main/open_game_engine_gui.py

# 3. compile JSON -> the .mem ROMs in /mem
python tools/main/compile_stage_to_mem.py
```

**Build & flash (hardware side):**

1. Open `vivado/ChronoForge.xpr` in Vivado.
2. Generate Bitstream, then Program the Basys3 over USB.
3. Connect VGA to a monitor — the game runs immediately. The four on-board push
   buttons move the player; slide switch **SW0** is reset.

Porting to a non-Basys3 board only needs the pin file
(`verilog/constrains/constains.xdc`) — see
[docs/hardware-guide.md](docs/hardware-guide.md).

> New here? Start with **[docs/python-guide.md](docs/python-guide.md)** to make a
> level, then **[docs/hardware-guide.md](docs/hardware-guide.md)** to put it on the
> board.
