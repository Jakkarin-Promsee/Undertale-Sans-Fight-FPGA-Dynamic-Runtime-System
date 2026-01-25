# ChronoForge FPGA Engine

## Technical Specification & Architecture Document

**Project Goal:**

- Let anyone build games on an FPGA board without touching hardware code
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

- **Zero-Instruction Overhead:** Unlike a CPU that fetches, decodes, and executes instructions one by one, ChronoForge is a **Direct-Logic Engine**. Every game event is a hardware state transition, eliminating the "bottleneck" of sequential execution.
- **Decentralized Processing:** Each module has its own specific duty and logic. This makes the event-driven strategy faster and more resource-efficient by avoiding a single master controller.
- **Massive Parallelism:** All game objects—triggers, colliders, and characters—are processed in parallel across dedicated hardware pipelines, allowing for consistent 640x480 @ 60Hz performance regardless of object density.
- **Hardware-Level Determinism:** By removing the OS and CPU interrupts, every frame is calculated with nanosecond precision. What you see in the compiler is exactly what the hardware executes, every single time.
- **The Performance Peak:** ChronoForge computes pixels for 60 dynamic triggers, 30 dynamic colliders, and 80 dynamic characters in **less than 4 clock cycles** without Spatial Partitioning—all within 18k LUTs and 7k FFs. It can handle up to 25k attacks/platforms and 75k character data points within just 225 KB of BRAM.

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

ChronoForge does not use a CPU, instruction stream, or script interpreter.  
Instead, it is designed to maximize performance and resource efficiency on low-end FPGA boards by driving all gameplay through three independent hardware timelines (event-drieven runtimes) implemented as ROM index counters:

- **Attack Timeline**
- **Platform Timeline**
- **Character Timeline**

Each timeline walks through its own ROM object list from index `0` to the terminal header (`FFF*`).  
Every object contains both **spatial data** and **temporal data** (`wait_time`, `destroy_time`).

Each timeline has its own internal wait counter. An object becomes active only when its wait counter reaches zero, after which the timeline advances to the next ROM entry.

This creates a **fully hardware-driven event scheduler:**

```bash
Runtime Counter -> wait Gate -> Object Index -> ROM -> Add wait -> Runtime Counter
```

Because each timeline advances independently, objects can overlap, interleave, and execute concurrently with **no branching, no script engine, and no CPU control logic.**

The **Attack Timeline** acts as the global epoch controller. When the attack index reaches its terminal header, the entire game resets. This allows **null attack objects** to be used as pure time delays, making it possible to script pauses, waves, and pacing directly in ROM.

**Conceptual View:**

```bash
Attack:    start ------> A0 ------> A1 -------------> A2 -> end -> reset

Platform:  start --> P0 -------------> P1 -----> P2 --> end

Character: start ->  C1 ---> C2 ------------------> C3 --> end
```

Each object type is implemented as a **dedicated hardware module** optimized for its role.
The three timelines are controlled by a **dynamic register system**, allowing the number of active Attack, Platform, and Character objects to be configured per game, per board, and per resource budget.

---

## What we do

- **Hardware Runtime Engine:**
  - Designed and built in Vivado + Verilog
  - Uses five main runtime pipelines for game stage, game ui, and trigger/collider/character object
  - Reads data from ROM (.mem files in hex form)

  - Configurable resource allocation amount:
    - 60 dynamic trigger objects (default)
    - 30 dynamic collider objects (default)
    - 80 dynamic character objects (default)

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
  - Uses python code to manage file stucture for easily to read and edit by human

    ```bash
    stage/
    ├── stage00.json
    ├── stage01.json
    └── ...
    ```

    ```bash
    stage_ui/
    ├── stage_ui_00.json
    ├── stage_ui_02.json
    └── ...
    ```

  - Uses simply python list to store each element and uses `for` loop for easily repeating item generate

    ```py
    # stage_01.json example
    import sys, os
    sys.path.append(os.path.abspath(os.path.join(os.path.dirname(**file**), '..', '..')))
    from interpret_langauge.game_class import GameStage, GameManager, AttackObject, PlatformObject

    def stage():
        stage = GameStage()

        # Game Manager Configuration (No player display)
        stage.game_manager = GameManager(stage=1, wait_time=1, gravity_direction=0, display_pos_x1=0, display_pos_y1=0, display_pos_x2=0, display_pos_y2=0)

        # Common Parameters
        ATTACK_SIZE = 20
        ATTACK_GAP = 30
        ATTACK_X = 85
        ATTACK_Y = 140

        # Initial Delay (2 seconds)
        stage.attack_objects.append(
            AttackObject(type=0, colider_type=0, movement_direction=2, speed=0, pos_x=0, pos_y=0, w=0, h=0, wait_time=2, destroy_time=0, destroy_trigger=2, )
        )

        # Helper: generate 10 row object
        def generate_row(attack_y):
            stage.attack_objects.extend([
                    AttackObject(type=0, colider_type=0, movement_direction=0, speed=0, pos_x=ATTACK_X + (ATTACK_SIZE + ATTACK_GAP)*i, pos_y=attack_y, w=ATTACK_SIZE, h=ATTACK_SIZE, wait_time=0, destroy_time=4, destroy_trigger=2, )
                    for i in range(10)
            ])

        # Repeating column generate
        for i in range(6):
            generate_row(ATTACK_Y + (ATTACK_SIZE+ATTACK_GAP)*i)

        # Last Delay (5 seconds)
        stage.attack_objects.append(
            AttackObject(type=0, colider_type=0, movement_direction=2, speed=0, pos_x=0, pos_y=0, w=0, h=0, wait_time=7, destroy_time=0, destroy_trigger=2, )
        )

        # Platform Placeholder (No Movement)
        stage.platform_objects.append(
            PlatformObject(movement_direction=2, speed=0, pos_x=0, pos_y=0, w=0, h=0, wait_time=0, destroy_time=0, destroy_trigger=2)
        )

        return stage
    ```

    ```python
    # stage_ui_01.json example
    import sys, os
    sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..')))
    from interpret_langauge.game_class import GameUIStage, GameUI, CharacterObject


    def stage():
        stage = GameUIStage()

        # Game UI Configuration (No player display)
        stage.game_ui = GameUI(show_healt_text=1, reset_character=1, transparent_out_screen_display=0, healt_current=96, healt_max=96, healt_bar_pos_x=190, healt_bar_pos_y=400, healt_bar_w=120, healt_bar_h=20, healt_bar_sensitivity=0.04, wait_time=1000)

        # Writing the string as each character object
        stage.character_objects.extend([
            CharacterObject(167 + (center_data.CHARACTER_W + center_data.GAP) * i, 74, ch)
            for i, ch in enumerate("GAMEPLAY SHOWCASE")
            if ch != " "
        ])

        return stage
    ```

  - Has python gui to visualize all object position to test before upload to board
  <p align="center" style="text-align: center;">
      <img src="docs\images\chonoforge_python_gui2.png" alt="Early Convergence Comparison" width="800px">
  </p>

---

## How much resource we takes

- **Current Board Utilization (Basys3):**

  | Resource | Utilization | Available | Board Usage % |
  | :------- | :---------- | :-------- | :------------ |
  | LUT      | 18015       | 20800     | 87%           |
  | FF       | 7196        | 41600     | 17%           |
  | BUFG     | 6           | 32        | 19%           |

  (Defalt: 60 dynamic attack, 30 dynamic platform, and 80 dynamic character)

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
├── docs/                ← Documentation assets (images, diagrams)
├── mem/                 ← Final compiled .mem ROM images loaded by the FPGA
├── synthesis/           ← Font and synthesis data (e.g. 17×17 glyphs)
├── tools/               ← Compiler, interpreter, and GUI tools
│   ├── main/            ← Game authoring workspace (users write here)
│   │   ├── stage/       ← Game stage logic (attack + platform objects)
│   │   ├── stage_ui/    ← UI and character objects
│   │   ├── compile_stage_to_json.py
│   │   ├── compile_stage_to_mem.py
│   │   └── open_game_engine_gui.py
│   ├── …                ← Internal processing layers
│   └── README.md        ← Interpreter / data format documentation
├── verilog/             ← All hardware source code
│   ├── constrains/
│   │   └── constrains.xdc
│   └── sources/
│       └── top/
│           └── topModule.v
├── vivado/              ← Vivado project and FPGA bitstream
│   └── ChronoForge.xpr
└── README.md            ← Project overview
```

---

# How to use it

## How to Code the Game (Game Author)

Game authors only work inside:

```bash
ChronoForge-FPGA-Engine/
├── tools/
│   ├── main/
│   │   ├── stage/        ← Game stage logic (attack + platform objects)
│   │   ├── stage_ui/     ← UI and character objects
│   │   ├── compile_stage_to_json.py
│   │   ├── compile_stage_to_mem.py
│   │   └── open_game_engine_gui.py
```

- `stage/` contains `.py` files defining **attack** and **platform** objects
- `stage_ui/` contains `.py` files defining **UI** and **character** objects

---

### 1. Game Design Concept

**Conceptual View (Timeline-based):**

```bash
Attack:    start ------> A0 ------> A1 -------------> A2 -> end -> reset

Platform:  start --> P0 -------------> P1 -----> P2 --> end

Character: start ->  C1 ---> C2 ------------------> C3 --> end
```

As explained in the **Overview**, this project uses **three different timelines** for object spawning.

**More Detail:**

```bash
(Attack and Platform)
Stage:    start ------> S0 ------> S1 -------------> S2 -> end -> reset

(Character and UI Prop)
StageUI:  start -> U0 -> U1 -> U2 -------------> U3 --> end
```

To keep UI efficient, we clearly separate it from the stage logic:

- **Stage** → only attack and platform spawning. The **Attack Timeline** acts as the global timeline. When this timeline ends, the game moves to the next stage.

- **StageUI** → characters and all UI properties. The **Character Timeline** acts as the global timeline. When this timeline ends, the game moves to the next stage ui.

Think of `Stage` and `StageUI` as an **object wrapper** to store game stage properties.

Both **Stage** and **StageUI** move to the next index once they finish spawning all objects inside. When the **Stage** reaches its last index, the **entire game resets back to the first stage**.

This design leads to two main folders:

- `stage/`
- `stage_ui/`

---

### 2. Writing a Stage (`stage/`)

Each stage is written in the following Python format:

```python
# Header import to let the compiler know the library path
import sys, os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..')))
from interpret_langauge.game_class import GameStage, GameManager, AttackObject, PlatformObject


def stage():
    # Game stage wrapper
    stage = GameStage()

    # Game manager configuration
    stage.game_manager = GameManager(...)

    # Attack object list (Require at least 1 object)
    stage.attack_objects.append(AttackObject(...))

    # Platform object list (Require at least 1 object)
    stage.platform_objects.append(PlatformObject(...))

    # Return game stage class
    return stage
```

#### `GameManager()` Attributes

- `stage` (0–254)
  - Stage number (0–255), for developer reference only

- `wait_time` (0–25.4 seconds)
  - Delay before moving to the next stage

- `gravity_direction` (0, 1)
  - `0`: no gravity
  - `1`: active gravity

- `display_pos_x1` (0–1024 px)
  - Top-left X of player zone

- `display_pos_x2` (0–1024 px)
  - Top-right X of player zone

- `display_pos_y1` (0–1024 px)
  - Bottom-left Y of player zone

- `display_pos_y2` (0–1024 px)
  - Bottom-right Y of player zone

#### `AttackObject()` and `PlatformObject()` Attributes

- `movement_direction` (0–7)
  - `0`: top
  - `1`: top-right
  - `2`: right
  - `3`: bottom-right
  - `4`: down
  - `5`: bottom-left
  - `6`: left
  - `7`: top-left

- `speed` (0–31)
  - Movement speed (`0` = stop)

- `pos_x` (0–1023 px)
  - Spawn X position (top-left)

- `pos_y` (0–1023 px)
  - Spawn Y position (top-left)

- `w` (0–1023 px)
  - Object width

- `h` (0–1023 px)
  - Object height

- `wait_time` (0–25.4 seconds)
  - Delay before spawning the next object

- `destroy_time` (0–254 seconds)
  - Force-destroy delay

- `destroy_trigger` (0, 2)
  - `0`: never destroy on hit
  - `2`: destroy when hitting display edge
  - (`1`: destroy when hitting player display edge — **not recommended**, ~200+ LUT per object)

#### Tip:

- You can use `w`=0 and `h`=0 to make non-display object and use `wait_time` as delay.
- You can use `display_pos_x1`=0, `display_pos_x2`=0, `display_pos_y1`=0, and `display_pos_y2`=0 to hide all display (making blank screen)

---

### 3. Writing a UI Stage (`stage_ui/`)

Each UI stage follows this format:

```python
# Header import to let the compiler know the library path
import sys, os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..')))
from interpret_langauge.game_class import GameUIStage, GameUI, CharacterObject


def stage():
    # Game UI stage wrapper
    stage = GameUIStage()

    # Game UI configuration
    stage.game_ui = GameUI(...)

    # Character object list (Require at least 1 object)
    stage.character_objects.append(CharacterObject(...))

    # Return game UI stage class
    return stage
```

#### `GameUI()` Attributes

- `show_healt_text` (0, 1)
  - Show "HP XXX/XXX"

- `reset_character` (0, 1)
  - Reset previous text for animation control

- `transparent_out_screen_display` (0, 1)
  - Hide attack/platform objects when outside the player screen
  - (Used to save hardware resources)

- `healt_current` (0–254)
  - Current HP (`0` = no change, except reset)

- `healt_max` (0–254)
  - Set max HP

- `healt_bar_pos_x` (0–1023 px)
  - HP bar X position (top-left)

- `healt_bar_pos_y` (0–1023 px)
  - HP bar Y position (top-left)

- `healt_bar_w` (0–1023 px)
  - HP bar width

- `healt_bar_h` (0–1023 px)
  - HP bar height

- `healt_bar_sensitivity` (0–2.54)
  - Damage sensitivity

- `reset_when_dead` (0, 1)
  - Reset all stage to 0 when hp is 0

- `wait_time` (0–25.4 seconds)
  - Delay before moving to next UI stage

#### `CharacterObject()` Attributes

- `character_pos_x` (0–1023 px)
  - Spawn X position

- `character_pos_y` (0–1023 px)
  - Spawn Y position

- `character_index` (`"A"–"Z"`, `"0"–"10"`)
  - Character symbol

#### Tip:

- You can use `healt_bar_w`=0, and `healt_bar_pos_h`=0 to hide all display UI

---

### 4. Python Loop Tip

As you know, all objects are stored inside Python lists ([]). This allows you to use both append() and extend() to generate objects programmatically.

```python
# for-loop style
for i in range(10):
    stage.attack_objects.append(AttackObject(pos_x=i, ...))


# list-comprehension style
stage.attack_objects.extend([
    AttackObject(pos_x=i, ...) for i in range(10)
])


# function-based loop
stage.attack_objects.extend(
    CreateRowObject(i) for i in range(5, 20, 5)
)
```

This pattern is very useful for creating:

- Bullet hell patterns

- Repeated platforms

- Symmetric or parametric attack layouts

Without manually writing each object one by one.

---

### 5. Build & Deploy Pipeline

1. Run `compile_stage_to_json.py`
   - Converts Python objects in `stage/` and `stage_ui/` into `.json`
   - File processing order follows **ASCII filename order** (defines stage sequence)
   - JSON is used by the Python GUI for visualization

2. Run `open_game_engine_gui.py`
   - Visually preview object positions and timing

3. Run `compile_stage_to_mem.py`
   - Converts JSON into `.mem` ROM data
   - Overwrites FPGA ROM data used by the hardware

4. Run Vivado flow
   - Synthesis
   - Implementation
   - Generate bitstream
   - Upload to FPGA board

---

## How to Configs Hardware Properties

This section describes how to configure hardware-level behavior of the ChronoForge FPGA Engine. These settings directly affect pin mapping, resource usage, timing, and overall system behavior.

Since changes here require hardware knowledge a bit and directly impact FPGA synthesis results. If you are using Xilinx Basys3 FPGA Board (Artix-7), You don't have to touch anything.

---

### 1. Hardware Input Pin Configuration

Controls how external signals are connected to the top module.

Only **one file** is edited:

```bash
ChronoForge-FPGA-Engine/
├── verilog/
│   └── constrains/
│       └── constains.xdc
```

(or relative path: `./verilog/constrains/constains.xdc`)

#### Common Pins

Search for these port names in the `.xdc` file:

- `clk`
  - Built-in generated main clock input

- `clk_reset`
  - Global reset pin

- `switch_up`, `switch_down`, `switch_left`, `switch_right`
  - Player control inputs

- `RED`, `GREEN`, `BLUE`
  - VGA color channels (4 wires per color)

- `HA`, `VS`
  - VGA horizontal / vertical sync

#### Constraint Format

Pin mapping follows this structure:

```xdc
set_property PACKAGE_PIN <on_board_pin> [get_ports <pin_name>]
```

Changing these mappings allows the engine to run on different FPGA boards without modifying Verilog logic.

---

### 2. Resource Allocation Amount

Controls **how many objects the hardware can handle simultaneously**.

Only **one file** is edited:

```bash
ChronoForge-FPGA-Engine/
├── verilog/
│   └── sources/
│       └── top/
│           └── topModule.v  ← Here
```

(or relative path: `./verilog/sources/top/topModule.v`)

#### Key Parameters

Search for these `localparam` definitions:

- `MAXIMUM_COLLIDER_OBJECT_AMOUNT`
- `MAXIMUM_TRIGGER_OBJECT_AMOUNT`
- `MAXIMUM_CHARACTER_AMOUNT`

#### What These Control

These parameters **directly define**:

- Number of hardware object slots instantiated
- Total LUT, FF, and BRAM usage
- Upper limit of simultaneous objects in gameplay

Increasing these values:

- Increases game complexity
- Increases FPGA resource usage

Decreasing these values:

- Saves hardware resources
- Limits maximum object count

This is a **compile-time hardware tradeoff**, not a runtime setting.

---

### 3. Hardware Clock Configuration

Controls clock domains used by each runtime subsystem.

Only **one file** is edited:

```bash
ChronoForge-FPGA-Engine/
├── verilog/
│   └── sources/
│       └── top/
│           └── topModule.v  ← Here
```

(or relative path: `./verilog/sources/top/topModule.v`)

#### Default Clock Requirement

- The default design requires a **100 MHz main clock**
- `topModule` has **only one external clock input**
- If your board provides 100 MHz, **no changes are required**

#### Clock Divider Parameters

Search for these parameters:

- `CLK_DIV_FACTOR_VGA`
  - VGA pixel clock divider
  - Requirement: `main_clock / CLK_DIV_FACTOR_VGA ≤ 25 MHz`
  - Used for 640×480 @ 60 Hz display

- `CLK_DIV_FACTOR_PLAYER_CONTROL`
  - Controls player movement scale, gravity, frame rate, button sensitivity
  - Default: `main_clock / CLK_DIV_FACTOR_PLAYER_CONTROL = 100 MHz` (100 FPS)

- `CLK_DIV_FACTOR_OBJECT_CONTROL`
  - Controls object movement speed, register sync, destroy timing
  - Default: `main_clock / CLK_DIV_FACTOR_OBJECT_CONTROL = 100 MHz` (100 FPS)

- `CLK_DIV_FACTOR_CENTI_SECOND`
  - Controls all time-counter modules
  - Requirement: `main_clock / CLK_DIV_FACTOR_CENTI_SECOND = 1000 Hz`
  - \*\*Because on product test, we saw that centi second isn't enough. Making we decided to use it as milli second. And this clk is so wild, making it's too hard to rename.

- `CLK_DIV_FACTOR_CALCULATION`
  - Controls calculation processes:
    - Runtime synchronization
    - Pixel color checks
    - Runtime communication
    - ROM index updates

  - Must be **faster than all other derived clocks** (except main)

#### Clock Architecture Notes

- Each runtime subsystem uses a **dedicated clock domain**
- All systems are synchronized through `clk_calculation`
- This design allows free scaling of gameplay speed without rewriting logic

In practice, `clk_calculation` usually dominates:

- Object register updates
- Object movement
- Object destruction
- Physics and player interaction

This clock directly affects gameplay feel and performance.

---

#### Hardware Note

All changes in this document affect **synthesis results**. After modification, you must:

- Re-run synthesis
- Re-run implementation
- Regenerate bitstream
- Reprogram the FPGA board

---

# How Hardware Circuit Works (Deep Detail)

## 1. Decentralized Processing Architecture

At its core, the engine utilizes a **decentralized, multi-clock, parallel processing architecture**. Rather than relying on a single sequential game loop, each processor (runtime) is assigned a very specific responsibility to maximize efficiency and determinism.

Each runtime _knows exactly what it must do_ and operates independently under its own clock domain.

| Processor        | Clock                | Description                                            |
| ---------------- | -------------------- | ------------------------------------------------------ |
| VGA Display      | `clk_vga`            | Pixel color multiplexer for all visible objects        |
| Player           | `clk_player_control` | Player logic: input, gravity, movement, wall collision |
| Time Counter     | `clk_centi_second`   | Global time source shared across all modules           |
| Stage            | `clk_calculation`    | Stage manager: attack / platform spawning logic        |
| Attack Object    | `clk_object_control` | Trigger-based objects (damage, events)                 |
| Platform Object  | `clk_object_control` | Collider-based objects (terrain, walls)                |
| Stage UI         | `clk_calculation`    | UI state control and character/UI spawning             |
| Character Object | `clk_calculation`    | UI character and visual-only entities                  |

> **Note on `clk_centi_second`:**
> Originally designed as a centisecond clock, real hardware testing revealed that 10 ms resolution was insufficient. As a result, this clock now operates effectively as a **millisecond clock**. The name remains unchanged due to its widespread use across the design.

---

## 2. Clock Architecture

The system uses multiple clock domains derived from the Basys3 **100 MHz main clock**, distributed via **BUFG (Global Clock Buffers)** to ensure low skew and reliable timing closure.

Clock separation is critical for deterministic behavior between:

- High-frequency pixel rendering (VGA)
- Medium-speed object updates
- Low-frequency event-driven logic

| Clock Domain         | Frequency | Rationale and Primary Function                                                          |
| -------------------- | --------- | --------------------------------------------------------------------------------------- |
| `clk_main`           | 100 MHz   | Core system clock for high-speed logic and inter-module handshakes                      |
| `clk_vga`            | 25 MHz    | VGA timing for 640×480 @ 60 Hz                                                          |
| `clk_player_control` | 100 Hz    | Player physics and input; decoupled for deterministic movement                          |
| `clk_object_control` | 100 Hz    | Non-player object movement and physics                                                  |
| `clk_centi_second`   | 1 kHz     | Global timing for `wait_time` and `destroy_time` counters                               |
| `clk_calculation`    | 1 kHz     | High-priority synchronization, object registration, collision logic, heavy calculations |

> `clk_calculation` is treated as the **highest-priority logic clock** (excluding VGA), ensuring all state transitions are fully synchronized before slower behavior clocks consume the results.

---

## 3. Sync / Update Handshake Protocol

All data transfer between parent and child modules is coordinated using a **two-wire handshake protocol**, synchronized at `clk_calculation` (1 kHz).

This guarantees data integrity across different clock domains with zero combinational dependency.

| Signal     | Direction      | Function                                                        |
| ---------- | -------------- | --------------------------------------------------------------- |
| `sync_*`   | Parent → Child | **Active-Low**: Requests the child to load data or begin a task |
| `update_*` | Child → Parent | **Active-High**: Indicates task completion and stable output    |

### Lifecycle (State Machine)

1. **Idle:** `sync = 1`, `update = 0`
2. **Data Setup:** Parent prepares input data
3. **Request:** Parent asserts `sync = 0`
4. **Load:** Child captures input data
5. **Execute:** Child processes the task
6. **Complete:** Child asserts `update = 1`
7. **Acknowledge:** Parent reads output and deasserts `sync = 1`
8. **Reset:** Child clears `update = 0`

**This mechanism allows us to:**

- Communicate safely across different clock speeds
- Verify completion from both parent and child sides
- Guarantee at least **three `clk_calculation` cycles** per transaction

---

## 4. Event-driven Runtime Concept

This design completely avoids:

- CPUs
- Instruction streams
- Script interpreters

The goal is **maximum performance, minimal redundancy, and full determinism**.

All gameplay logic is preprocessed and stored in ROM. Each ROM line represents **one event**, already optimized and encoded in hex form.

Examples of stored data:

- `spawn_position_x`, `spawn_position_y`
- `movement_direction`
- `movement_speed`
- lifetime and destroy rules

At runtime:

1. ROM data is loaded into registers
2. Each runtime autonomously executes its responsibility
3. No central scheduler is required

State-Driven Autonomy behavior:

- Initialize position from ROM
- Increment position based on direction and speed
- Trigger events on collision
- Self-destruct on timeout or screen exit

This allows **manual, event-level optimization** instead of generic instruction execution.

### ROM Structure

- `game_manager.mem` (Stage)
  - `attack_object.mem`
  - `platform_object.mem`

- `game_ui.mem` (Stage UI)
  - `character_object.mem`

- `font_data.mem` (17×17 bitmap font)

([Go to 2. Bit Compression Strategy for more detail (click here)](#2-bit-compression-strategy))

---

## 5. Runtime Maps

This section exposes the real circuit structure. Due to complexity, it is divided into focused sub-maps.

---

### 5.1 Clock Map

```
input -> clk_main (100MHz)
|
├── clk_div -> clk_player_control (100Hz)
|   └── player_position_controller
|
├── clk_div -> clk_calculation (100Hz)
|   ├── game_runtime
|   ├── game_ui_runtime
|   ├── multi_object_collider_runtime
|   |   └── object_position_controller (clk_object_control)
|   ├── multi_object_trigger_runtime
|   |   └── object_position_controller (clk_object_control)
|   |
|   ├── game_manager_rom
|   ├── attack_object_rom
|   ├── platform_object_rom
|   ├── game_ui_rom_reader
|   ├── character_object_rom_reader
|   └── font_data_rom_reader
|
├── clk_div -> clk_vga (100Hz)
|   └── vga_translator
|       └── universal_renderer (multiplexor, 100% LUT)
|
├── clk_div -> clk_object_control (100Hz)
|   ├── game_display_controller
|   └── *object_position_controller (link in multi object runtime)
|
├── clk_div -> clk_centi_second (1 kHz)
|   └── *... (link in most runtime and module)
|
└── other tools
    ├── player_renderer (Wires, 100% LUT)
    ├── game_display_renderer (Wires, 100% LUT)
    └── object_renderer (Wires, 100% LUT)
```

Clock depth interpretation:

- **100 MHz**: deepest hardware layer
- **25 MHz**: pixel generation
- **1 kHz**: event-driven synchronization layer
- **100 Hz**: behavior and movement layer

---

### 5.2 Synchronization Map

```bash
player_controller(*Mother class)
└── player_renderer
```

```bash
game_runtime (*Mother class, Control Stage/Attack/Platform index)
|
├── game_manager_rom (load data)
├── attack_object_rom (load data)
├── platform_object_rom (load data)
|
├── multi_object_collider_runtime (pull data, manage objects list, render pixels)
|   └── List of Module (dynamic object list)
|       ├── object_position_controller (assign data)
|       └── object_renderer (wired the pixel condition, 100% LUT)
|
├── multi_object_trigger_runtime (pull data, manage objects list, render pixels)
|   └── List of Module (dynamic object list)
|       ├── object_position_controller (assign data)
|       └── object_renderer (wired the pixel condition, 100% LUT)
|
└── game_display_controller (pull data, update display properties)
    └── game_display_renderer (wired the pixel condition, 100% LUT)
```

```bash
game_ui_runtime(*Mother class, Control StageUI/Character index, Holding dynimic list itself)
|
├── font_data_rom_reader (load data)
├── character_object_rom_reader (load data)
└── game_ui_rom_reader (load data)
```

```bash
universal_renderer(Multiplexor prioritize pixels wires from 3 Mother class modules)
└── RGB (4 wires for each)
```

Responsibilities are cleanly separated into three core domains:

1. **player_controller** – everything related to the player entity
2. **game_runtime** – all non-player gameplay objects
   - **object_position_controller** - (duplicated) all object movement control
   - **object_renderer** - (duplicated) all object render
3. **game_ui_runtime** – UI, HUD, and visual-only entities

---

### 5.3 Object Communication Map

By clearly defining the functional boundaries of each circuit segment, we can design the most efficient direct-wire communication between two event-driven runtimes. This minimizes propagation delay and computational overhead.

**Architectural Logic:**

- **Trigger Systems:** The player is mapped directly to all trigger objects to establish damage rules.

- **Collision Systems:** The player is mapped directly to all collider objects to establish movement constraints.

- **Register Properties:** Game state properties are linked to all objects to manage destruction rules.

Each object functions as an State-Driven Autonomy module. Because these modules process data internally, the main system no longer needs to assign or manage their specific compute cycles.

```bash
player_controller ─┬─> multi_object_trigger_runtime ─> game_ui_runtime
                   └─> multi_object_collider_runtime ─> player_controller
```

Optimization Strategies
To minimize wiring complexity, the following logic is implemented:

1. **Multi-Object Polling via Clock Gating:** We utilize a `for` loop to scan multiple objects. This logic executes on every `clk_calculation` cycle. By running this check at 1 kHz while the mainboard clock operates at 100 MHz, we ensure more than enough overhead for real-time processing.

2. **Direct Player-Trigger Interconnect:** The player position is pulled directly into the `multi_object_trigger_runtime`. Since the player uses a fixed 32-wire bus and each trigger object utilizes a 32-wire memory layout (held in Flip-Flop position memory), we can detect overlays via a simple loop. When an overlay is detected, a `High` signal is sent to the `game_ui_runtime` to reduce HP. If HP reaches zero, a `High` signal is dispatched to the `game_runtime` to initiate a global reset.

3. **Proximity-Based Collision Feedback** The player position is fed into the `multi_object_collider_runtime` to calculate the nearest object. Using a high-speed loop, the system identifies the closest proximity and sends this data back to the `player_controller`. The controller then treats this object as a physical boundary, effectively gating or blocking movement.

---

### 5.4 Pixel Communication Map

```bash
player_controller ─────────────┬──> universal_renderer ─> RGB
multi_object_trigger_runtime ──┤
multi_object_collider_runtime ─┤
game_display_controller ───────┘
```

Due to the **4-cycle pixel budget**, traditional multiplexing is insufficient.

Rendering uses:

- Bitwise brute-force evaluation
- Fixed-priority logic
- Only **8 conditional layers** total
  Including collider, trigger, display border, player, healt bar border, healt bar, character, and background.

---

### 5.5 Top Module Map

```bash
TopModule
├── clk_div_vga
├── clk_div_player_control
├── clk_div_object_control
├── clk_div_centi_second
├── clk_div_calculation
|
├── vga_translator
|
├── game_runtime
|   └── game_manager_rom
├── attack_object_rom
├── platform_object_rom
|
├── game_ui_runtime
|   ├── font_data_rom_reader
|   ├── character_object_rom_reader
|   └── game_ui_rom_reader
|
├── game_display_controller
├── game_display_renderer
|
├── multi_object_collider_runtime
|   ├── object_position_controller[]
|   └── object_renderer[]
|
├── clk_div_vga
|   ├── object_position_controller[]
|   └── object_renderer[]
|
├── player_position_controller
├── player_renderer
|
└── universal_renderer
```

This represents the complete physical hierarchy of the engine as synthesized on FPGA.

---

# How compiler and interpret class works (Deep Detail)

This section will explains how **high-level Python stage definitions** are compressed and translated into **hardware-friendly `.mem` ROM formats**.

## 1. Stage vs StageUI Timeline Model

```bash
(Attack and Platform)
Stage:    start ------> S0 ------> S1 -------------> S2 -> end -> reset

(Character and UI Prop)
StageUI:  start -> U0 -> U1 -> U2 -------------> U3 --> end
```

As we explain above:

- **Stage** controls Attack + Platform spawning, go to next Stage when run all Attack Object.
- **StageUI** controls Character + UI behavior, go to next StageUI when run all Character Object.

The **Stage timeline is global**. When Stage reaches its end:

- All objects are flushed
- Both Stage and StageUI reset to index 0
- Game start again

Utilizes 0xFFFFF as a EOF (End-of-File) marker for Stage/UI data to ensure deterministic termination and prevent memory overflow.

---

## 2. Bit Compression Strategy

All Python objects are compiled into **fixed-width bit records**.

- Each `.mem` file represents a ROM
- Each line = one object or one stage record
- All fields use **power-of-two bit widths**

This allows:

- Simple address-based fetching
- No variable-length decoding
- Fully parallel hardware pipelines

We have 6 mains file (`.mem`):

- `game_manager.mem` (Stage)
  - `attack_object.mem` (Attack Object)
  - `platform_object.mem` (Platform Object)
- `game_ui` (StageUI)
  - `character_object` (Character Object)
- `font_data.mem` (17\*17 Font Data)

---

### 2.1. `game_manager.mem` Structure (72 Bits)

Controls **scene flow** and initial loading behavior for Attack and Platform objects.

| Field               | Bit Width | Description                                            |
| ------------------- | --------- | ------------------------------------------------------ |
| `stage`             | 8 bits    | Stage / Scene ID (0–255, developer reference)          |
| `attack_amount`     | 10 bits   | Number of Attack records to load from `attack.mem`     |
| `platform_amount`   | 10 bits   | Number of Platform records to load from `platform.mem` |
| `gravity_direction` | 3 bits    | Gravity vector (8-way, or 0 = disabled)                |
| `display_pos_x1`    | 8 bits    | Viewport top-left X                                    |
| `display_pos_y1`    | 8 bits    | Viewport top-left Y                                    |
| `display_pos_x2`    | 8 bits    | Viewport bottom-right X                                |
| `display_pos_y2`    | 8 bits    | Viewport bottom-right Y                                |
| `wait_time`         | 8 bits    | Delay before next Stage (centi-seconds)                |
| `free (unused)`     | 1 bit     | Reserved                                               |

Total: **72 bits per Stage record**

---

### 2.2. `attack.mem` Structure (72 Bits)

Attack objects are treated as **Trigger-Only** entities.

| Field                | Bit Width | Description                                 |
| -------------------- | --------- | ------------------------------------------- |
| `type`               | 5 bits    | Attack type / damage profile / animation ID |
| `collider_type`      | 2 bits    | Trigger shape (Square, Capsule, Tilt L/R)   |
| `movement_direction` | 3 bits    | Initial 8-way direction                     |
| `speed`              | 5 bits    | Initial speed (32 levels)                   |
| `pos_x`              | 8 bits    | Spawn X position                            |
| `pos_y`              | 8 bits    | Spawn Y position                            |
| `w`                  | 8 bits    | Width                                       |
| `h`                  | 8 bits    | Height                                      |
| `wait_time`          | 8 bits    | Spawn delay (centi-seconds)                 |
| `destroy_time`       | 8 bits    | Forced destroy timer                        |
| `destroy_trigger`    | 2 bits    | Destroy condition                           |
| `free (unused)`      | 7 bits    | Reserved                                    |

Total: **72 bits per Attack object**

---

### 2.3. `platform.mem` Structure (64 Bits)

Platform objects are treated as **Collider-Only** entities.

| Field                | Bit Width | Description                 |
| -------------------- | --------- | --------------------------- |
| `movement_direction` | 3 bits    | Initial 8-way direction     |
| `speed`              | 5 bits    | Initial speed               |
| `pos_x`              | 8 bits    | Spawn X position            |
| `pos_y`              | 8 bits    | Spawn Y position            |
| `w`                  | 8 bits    | Width                       |
| `h`                  | 8 bits    | Height                      |
| `wait_time`          | 8 bits    | Spawn delay (centi-seconds) |
| `destroy_time`       | 8 bits    | Forced destroy timer        |
| `destroy_trigger`    | 2 bits    | Destroy condition           |
| `free (unused)`      | 6 bits    | Reserved                    |

Total: **64 bits per Platform object**

---

### 2.4. `game_ui.mem` Structure (Per StageUI)

Controls **UI flow** and Character loading behavior.

| Field                            | Bit Width | Description                               |
| -------------------------------- | --------- | ----------------------------------------- |
| `show_healt_text`                | 1 bit     | Show "HP XXX/XXX"                         |
| `reset_character`                | 1 bit     | Reset previous character                  |
| `transparent_out_screen_display` | 1 bit     | Hide objects outside player screen        |
| `reset_when_dead`                | 1 bit     | Reset all stages when HP = 0              |
| `character_amount`               | 10 bits   | Number of Character records               |
| `healt_current`                  | 8 bits    | Current HP                                |
| `healt_max`                      | 8 bits    | Max HP                                    |
| `healt_bar_pos_x`                | 8 bits    | HP bar X position                         |
| `healt_bar_pos_y`                | 8 bits    | HP bar Y position                         |
| `healt_bar_w`                    | 8 bits    | HP bar width                              |
| `healt_bar_h`                    | 8 bits    | HP bar height                             |
| `healt_bar_sensitivity`          | 7 bits    | Amount of HP that get from Attack Object  |
| `wait_time`                      | 16 bits   | Delay before next StageUI (centi-seconds) |
| `free (unused)`                  | 3 bits    | Reserved                                  |

Total: **88 bits per StageUI record**

---

### 2.5. `character_object.mem` Structure

Character objects are treated as **UI entities**.

| Field             | Bit Width | Description  |
| ----------------- | --------- | ------------ |
| `character_pos_x` | 8 bits    | X position   |
| `character_pos_y` | 8 bits    | Y position   |
| `character_w`     | 8 bits    | Width        |
| `character_h`     | 8 bits    | Height       |
| `character_index` | 8 bits    | Character ID |

Total: **32 bits per Character object**

---

### 2.6. Compress Summary

- All **pixel-related** variable including `pos_x`, `pos_y`, `w`, and `h` will be divided by 4 to make data store is more efiicient. we will be able to keep 0-1024 px scales in 0-255 number.

- All **time-related** variable including `wait_time` and `destroy_time` will be divided by 10 to make easily to write by human. Caues we write 25.5 second instead 255 centi-second.

---

### 2.7. Design Philosophy Summary

- All `.mem` files are **static ROMs**
- No dynamic memory, no heap, no pointer chasing
- Every bit is intentional
- Unused bits are reserved for future expansion

This design enables:

- Fully deterministic gameplay
- Precise resource estimation
- Stable timing closure on FPGA

This is a **hardware-first game engine**, not a software runtime.

---

## 3. Compiler Strategy

This section describes the **full compilation pipeline**, from human‑friendly Python code down to FPGA‑readable `.mem` files. The compiler is designed as a **meaning‑stack**, where each layer adds structure and intent while remaining mechanically translatable to the layer below.

```
Python Class  →  JSON Source  →  JSON Decode  →  MEM (ROM)
```

Each layer serves a distinct role:

- **MEM (Machine Level)**
  Directly consumed by the FPGA ROM reader. Compact, deterministic, and not human‑readable.

- **JSON Decode (Structural Level)**
  A normalized, object‑type–separated representation. Each JSON file contains **only one object type**, which makes it machine‑friendly but harder for humans to reason about stage flow.

- **JSON Source (Scene Level)**
  Human‑readable stage and StageUI descriptions. Each file represents **one stage or one StageUI**, containing all related objects (manager, attacks, platforms, UI, characters).

- **Python Class (Authoring Level)**
  The highest‑level interface for users. `Stage` and `StageUI` classes provide programmability (loops, reuse, procedural generation) while remaining fully deterministic.

---

### 3.1 JSON Source → MEM

```
ChronoForge-FPGA-Engine/
├── mem/     ← Compiler ouput
├── tools/
│   ├── compiler/
│   │   ├── json_encoders.py        ← Bit‑level encoding definitions
│   │   └── json_to_mem_compiler.py ← MEM compiler entry
│   └── json-source-decode/         ← Compiler input (normalized JSON)
```

#### `json_encoders.py`

This file defines how structured data is compressed into fixed‑width bitfields.

**1. Decimal → Bit Packing**

```python
pack_bits(value, width, entry_index=None, field_name=None)
```

- Converts integer values into fixed‑width binary strings
- Performs overflow checking
- Uses `entry_index` and `field_name` for precise error diagnostics

**2. Object Encoder Functions**

```python
def encode_object(entry, index=None):
    bits = ""
    bits += pack_bits(int(entry["pos_x"] / 4), 8, index, "pos_x")
    bits += pack_bits(int(entry["pos_y"] / 4), 8, index, "pos_y")
    return bits
```

- One encoder per object type (Stage, Attack, Platform, UI, Character)
- Responsible for **field order**, **scaling**, and **bit allocation**

**3. Binary → Hex Conversion**

```python
bin_to_hex(bitstring)
```

- Converts final bitstrings into ROM‑friendly hexadecimal lines

---

#### `json_to_mem_compiler.py`

The main workflow is implemented in `build_mem_files()`.

**Compilation Task Definition**

Each `.mem` file is generated by a dedicated task:

```python
compilation_tasks = [
  {
      "name": "Game Manager",
      "json_path": os.path.join(UNIFIED_JSON_DIR, "game_manager.json"),
      "mem_path": os.path.join(MEM_OUTPUT_DIR, "game_manager.mem"),
      "encoder": encode_game_manager
  },
  {
      "name": "Attack Objects",
      "json_path": os.path.join(UNIFIED_JSON_DIR, "attack_object.json"),
      "mem_path": os.path.join(MEM_OUTPUT_DIR, "attack_object.mem"),
      "encoder": encode_attack
  },
  {
      "name": "Platform Objects",
      "json_path": os.path.join(UNIFIED_JSON_DIR, "platform_object.json"),
      "mem_path": os.path.join(MEM_OUTPUT_DIR, "platform_object.mem"),
      "encoder": encode_platform
  },
  {
      "name": "Game UI",
      "json_path": os.path.join(UNIFIED_JSON_DIR, "game_ui.json"),
      "mem_path": os.path.join(MEM_OUTPUT_DIR, "game_ui.mem"),
      "encoder": encode_ui
  },
  {
      "name": "Character Object",
      "json_path": os.path.join(UNIFIED_JSON_DIR, "character_object.json"),
      "mem_path": os.path.join(MEM_OUTPUT_DIR, "character_object.mem"),
      "encoder": encode_character
  }
]
```

**Compilation Loop**

- One JSON entry → one ROM line
- Deterministic ordering

```python
for idx, entry in enumerate(data_list):
    bitstring = task["encoder"](entry, idx)
    line = bin_to_hex(bitstring)
    lines.append(line)
```

This step completes the transformation from structured data into FPGA‑readable ROM images.

---

### 3.2 JSON Source → JSON Decode

```
ChronoForge-FPGA-Engine/
├── compiler/
│   ├── sorce_stage_to_json_compiler.py     ← Compiler
│   └── sorce_stage_ui_to_json_compiler.py  ← Compiler
├── json_stage_source/    ← Compiler input
├── json_stage_ui_source/ ← Compiler input
├── json_source_decode  ← Compiler output
```

Purpose:

- Flatten **stage‑centric JSON** into **object‑type‑centric JSON**
- Enable fixed‑order ROM generation

**Stage Compiler**

- Input: `json_stage_source/`
- Output: `json_source_decode/`
- Extracts:
  - `game_manager`
  - `attack_object`
  - `platform_object`

**StageUI Compiler**

- Input: `json_stage_ui_source/`
- Output: `json_source_decode/`
- Extracts:
  - `game_ui`
  - `character_object`

This step bridges **scene logic** and **hardware memory layout**.

---

### 3.3 Python Class → JSON Source

```
ChronoForge-FPGA-Engine/
├── tools/
│   ├── main/
│   │   ├── stage/    ← Compiler input
│   │   ├── stage_ui/ ← Compiler input
│   │   └── compile_stage_to_json.py ← Compiler
│   ├── json_stage_source/     ← Compiler output
│   └── json_stage_ui_source/  ← Compiler output
```

Python Class just hold everylabel JSON Source have:

- `Stage` class is each stage in `json_stage_source`
- `StageUI` class is each stage ui in `json_stage_ui_sorce`

Using simple JSON writing library:

- All `.py` files are discovered and sorted by ASCII order
- Each file exposes a `stage()` function
- `stage()` returns a `Stage` or `StageUI` instance
- Write in to JSON Source path

The compiler serializes:

- Object lists
- Timing metadata
- Scene‑level configuration

into **JSON Source**, preserving author intent while remaining deterministic.

---

### 3.4 Main Handle Compiler

```
ChronoForge-FPGA-Engine/
├── mem/ ← Compiler output
├── tools/
│   ├── compiler/
│   │   └── main_compiler.py  ← Main Handle Compiler
│   ├── json_stage_source/    ← Compiler input
│   ├── json_stage_ui_source/ ← Compiler input
│   └── json_stage_decode/    ← Passage
```

`main_compiler.py` orchestrates:

1. JSON Source → JSON Decode
2. JSON Decode → MEM

Input paths are fixed by convention, allowing the pipeline to run without configuration overhead.

---

### 3.5 Main User Workspace

```
ChronoForge-FPGA-Engine/
├── mem/ ← compile target
├── tools/
│   ├── main/
│   │   ├── stage/    ← Compiler input
│   │   ├── stage_ui/ ← Compiler input
│   │   ├── compile_stage_to_json.py  ← Compiler
│   │   └── compile_stage_to_mem.py   ← link to Main Handle Compiler
│   ├── json_stage_source/    ← Compiler output (link to Main Handle Compiler)
│   └── json_stage_ui_source/ ← Compiler output (link to Main Handle Compiler)
```

The `main/` directory acts as the **authoring workspace**:

- Users only interact with Python
- All compiler complexity is hidden behind fixed paths and scripts
- Ensures clean separation between **engine internals** and **game logic**

This structure allows ChronoForge to function as a **hardware‑targeted game compiler**, not merely a data exporter.
