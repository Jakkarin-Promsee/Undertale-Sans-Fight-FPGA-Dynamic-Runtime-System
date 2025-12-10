# ChronoForge FPGA Engine: Technical Specification and Architecture Document

**Target Platform:** Xilinx Basys3 FPGA Board (Artix-7)
**Primary Application:** Deterministic 2D Game Engine (640x480 @ 60Hz)
**Current Architecture Version:** V4
**Date:** December 10, 2025

---

## 1. Executive Summary

The ChronoForge FPGA Engine is a Verilog-based, hardware-accelerated 2D game platform designed for the Basys3 board. Its core innovation lies in a **decentralized, multi-clock, parallel processing architecture** that guarantees highly deterministic timing and predictable object-lifecycle management. The system is driven by a custom Python-based toolchain that compiles high-level JSON scene descriptions into dedicated binary ROM files (`.mem`), enabling rapid level design while maintaining the performance and accuracy of a pure hardware implementation. Key features include a robust **Sync/Update Handshake Protocol** for inter-module communication and a specialized rendering pipeline optimized for resource efficiency.

---

## 2. Clocking and Synchronization Architecture

The system utilizes five clock domains derived from the Basys3 100 MHz main clock using **BUFG (Buffer Global)** resources to ensure low-skew distribution and robust timing closure across all crucial subsystems. This isolation is essential for maintaining deterministic behavior between fast (VGA) and slow (Game Logic) modules.

| Clock Domain         | Frequency | Rationale and Primary Function                                                                                                       |
| :------------------- | :-------- | :----------------------------------------------------------------------------------------------------------------------------------- |
| `clk_main`           | 100 MHz   | Core system clock for all high-speed logic and data transfer/handshake operations.                                                   |
| `clk_vga`            | 25 MHz    | Dedicated clock for the Video Graphics Array (VGA) subsystem, specifically timing the 640×480 @ 60 Hz display standard.              |
| `clk_player_control` | 100 Hz    | Manages all player-related physics, input, gravity, and movement. Decoupled for deterministic gameplay updates.                      |
| `clk_object_control` | 100 Hz    | Manages all non-player object movement and physics (e.g., attacks, projectiles). Isolated from player logic for safety and clarity.  |
| `clk_centi_second`   | 100 Hz    | Global timing source for all **wait_time** and **destroy_time** counters across the system. (10ms resolution).                       |
| `clk_calculation`    | 1 kHz     | High-priority processing for complex, multi-cycle tasks such as object registration, collision system logic, and heavy calculations. |

### 2.1 Sync/Update Handshake Protocol

All data transfer and control flow between parent and child modules are mediated by a two-wire handshake to ensure data integrity and zero-delay synchronization at 100 MHz.

| Signal     | Direction                  | Function                                                                                                   |
| :--------- | :------------------------- | :--------------------------------------------------------------------------------------------------------- |
| `sync_*`   | Parent $\rightarrow$ Child | **Active-Low:** Signals the child to begin processing the task or loading new data.                        |
| `update_*` | Child $\rightarrow$ Parent | **Active-High:** Signals the parent that the child has completed the given task and output data is stable. |

**Lifecycle Example (State Machine):**

1. **Idle:** `sync=1`, `update=0`.
2. **Task Request:** Parent sets **`sync = 0`**.
3. **Task Execution:** Child loads data, executes task, and upon completion, sets **`update = 1`**.
4. **Acknowledgment:** Parent detects `update = 1`, retrieves data, and sets **`sync = 1`**.
5. **Reset:** Child detects `sync = 1`, and sets **`update = 0`** to return to Idle.

---

## 3. Game Runtime Pipeline and Data Structure

The engine's execution flow is orchestrated by the **Game Manager Runtime**, which continuously reads a sequence of game states from dedicated ROM files.

### 3.1 `game_manager.mem` Structure (Per Stage)

This structure controls scene flow, including the initial loading parameters for the Attack and Platform objects.

| Field               | Bit Width | Description                                                             |
| :------------------ | :-------- | :---------------------------------------------------------------------- |
| `stage`             | $2^8$     | Stage/Scene ID (Up to 256 unique stages).                               |
| `attack_amount`     | $2^{10}$  | Number of Attack records to load from `attack.mem`.                     |
| `platform_amount`   | $2^{10}$  | Number of Platform records to load from `platform.mem`.                 |
| `gravity_direction` | $2^3$     | Direction of the gravity vector (8-way or 0 for none).                  |
| `display_pos_x1/y1` | $2^8$     | Top-left corner of the viewport/scrolling region (x1, y1).              |
| `display_pos_x2/y2` | $2^8$     | Bottom-right corner of the viewport/scrolling region (x2, y2).          |
| `wait_time`         | $2^8$     | The delay (in centi-seconds) before advancing to the next stage record. |

### 3.2 Object ROM Structures

Object properties are stored in separate, parallel ROMs, allowing the Game Manager Runtime to initiate object spawns by reading sequences of records. All position and size values are scaled by a factor of 4 (i.e., $2^8$ bits $\times 4 \rightarrow 10$-bit final coordinate) to provide sub-pixel movement or higher resolution.

#### A. `attack.mem` Structure

Attack objects are treated as **Trigger-Only** entities.

| Field                | Bit Width      | Description                                                          |
| :------------------- | :------------- | :------------------------------------------------------------------- |
| `type`               | $2^5$          | Attack type (e.g., damage profile, animation ID).                    |
| `colider_type`       | $2^2$          | Shape of the trigger box (Square, Circle/Capsule, Tilt Left/Right).  |
| `movement_direction` | $2^3$          | Initial 8-way direction vector.                                      |
| `speed`              | $2^5$          | Initial object speed (32 levels).                                    |
| `pos_x/y, w/h`       | $4 \times 2^8$ | Position (x, y) and Dimension (width, height).                       |
| `wait_time`          | $2^8$          | Delay before this specific attack object is spawned (centi-seconds). |
| `destroy_time`       | $2^8$          | Lifetime before forced destruction (centi-seconds).                  |
| `destroy_trigger`    | $2^2$          | Condition for object removal (e.g., Out-of-Screen, Hit-Player).      |

#### B. `platform.mem` Structure

Platform objects are treated as **Collider-Only** entities.

| Field                | Bit Width      | Description                                                            |
| :------------------- | :------------- | :--------------------------------------------------------------------- |
| `movement_direction` | $2^3$          | Initial 8-way direction vector.                                        |
| `speed`              | $2^5$          | Initial object speed (32 levels).                                      |
| `pos_x/y, w/h`       | $4 \times 2^8$ | Position (x, y) and Dimension (width, height).                         |
| `wait_time`          | $2^8$          | Delay before this specific platform object is spawned (centi-seconds). |
| `destroy_time`       | $2^8$          | Lifetime before forced destruction (centi-seconds).                    |
| `destroy_trigger`    | $2^2$          | Condition for object removal.                                          |

---

## 4. Multi-Object Runtime Subsystems

Object handling is offloaded to two parallel, decentralized runtime modules operating at **1 kHz** (`clk_calculation`).

### 4.1 `multi_object_collider_runtime` (Platforms)

### 4.2 `multi_object_trigger_runtime` (Attacks)

**Architecture:** Each multi-object runtime acts as a resource manager for an array of $N$ **Single-Object Runtime** sub-modules.

1. **New Object Registration:** When the **Game Runtime** completes an object-spawn handshake, it initiates a **`sync_position`** signal.
2. **Resource Allocation:** The Multi-Object Runtime checks its internal **`iterator_ready_state[N]`** array to find the first available (free) Single-Object Runtime.
3. **Data Push:** The data from the Game Runtime is pushed to the newly allocated Single-Object Runtime.
4. **Decentralized Lifecycle:** The Single-Object Runtime becomes active, calculating its own position/movement and decrementing its `destroy_time` counter. When its `destroy_trigger` condition is met (e.g., time expires, off-screen, hit player), the module sets its state to **Free**, which updates the shared `iterator_ready_state[N]`.

This fully decentralized approach means object cleanup and destruction are handled by the object itself, freeing up the central runtimes for immediate registration of new objects.

---

## 5. Collision and Trigger Detection

The system employs an efficient, low-wire count method for player interaction.

1. **Minimal Player Interface:** The **Player Controller** module only outputs its current position and size: (`player_x`, `player_y`, `player_w`, `player_h`).
2. **Collider Ground Check (Example):**
   - The **Multi-Object Collider Runtime** receives player data.
   - It iterates through all active Platform objects.
   - It filters objects to those **below** the player and within the player's X-range.
   - It selects the **highest Y-coordinate** platform surface.
   - Output is sent back to the Player Controller: `is_collider_ground_player` (Boolean) and the integer `collider_ground_y_player`.
3. **2-Pixel Buffer:** To maintain stability on moving platforms and prevent jitter, an upward-moving platform's collision response incorporates a 2-pixel buffer, effectively pushing the player up without requiring immediate player velocity calculation.
4. **Trigger Check:** The **Multi-Object Trigger Runtime** performs simple bounding box overlap checks between the player and all active Attack objects.

---

## 6. Rendering Pipeline Optimization (VGA Module)

The VGA module operates at 25 MHz (`clk_vga`). The rendering strategy is optimized to minimize the use of scarce FPGA Block RAM (BRAM) or Flip-Flops (Registers) for object layering.

1. **Player-Centric Register Window:** A small, high-speed register bank is used to hold the color data for the area immediately surrounding and occupied by the player. This **register window** stores the final, prioritized color of all overlapping objects within this critical region.
2. **Global Pixel Compare:** For all pixels outside the player register window, the final output color is determined by a simple, cascaded **if-else priority structure** (background $\rightarrow$ platform $\rightarrow$ attack $\rightarrow$ other) based on coordinate comparison.

This method achieves efficient object layering and minimizes resource usage for the majority of the screen area, while guaranteeing that complex overlaps around the player are handled instantly and accurately.

---

## 7. Development and Toolchain

### 7.1 JSON-to-MEM Compiler

A Python compiler (`json_to_mem_compiler.py`) acts as the front-end for level design.

| Input JSON          | Output Binary      | Description                          |
| :------------------ | :----------------- | :----------------------------------- |
| `game_manager.json` | `game_manager.mem` | Stage sequencing and object amounts. |
| `attack.json`       | `attack.mem`       | Attack object data records.          |
| `platform.json`     | `platform.mem`     | Platform object data records.        |

The compiler includes validation logic to ensure all values adhere to the specified bit constraints (e.g., $2^8$, $2^{10}$) before generating the `.mem` files for Verilog `$readmemh()` initialization.

### 7.2 File Structure

The project employs a modular and clearly organized file structure:

```bash
Project/
/src
  /runtime
  /collider
  /trigger
  /vga
  /player
  /objects
/mem
  game_manager.mem
  attack.mem
  platform.mem
/tools
  json_to_mem_compiler.py
/docs
  README.md
```

---

## 8. Future Roadmap

- **Advanced Collider Types:** Implementation of circle, capsule, and slope collision logic in the Collider Runtime.
- **Sprite Engine:** Integrating a hardware-based DMA-style sprite or tile-map engine to improve rendering efficiency and complexity.
- **Audio Controller:** Addition of a dedicated audio synthesizer or playback module.
- **Custom Scripting Language:** Replacing the current JSON format with a minimal, domain-specific language (DSL) and interpreter for enhanced level-of-detail control.

---
