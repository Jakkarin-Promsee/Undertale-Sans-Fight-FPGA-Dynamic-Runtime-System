# AGENTS.md

Guidance for AI coding agents working in the **ChronoForge FPGA Engine** repo.

> **Single source of truth: [`CLAUDE.md`](CLAUDE.md).** It is the full repo map —
> data pipeline, hardware architecture, ROM bit formats, clock domains, and
> gotchas. Read it first. This file is the short version so any agent picks up the
> essentials even if it only reads `AGENTS.md`.

## What this project is

A **pure-hardware 2D game engine** for the Xilinx Basys3 (Artix-7) FPGA — no CPU,
no ISA, no OS. Game logic is authored in Python, compiled to fixed-width hex ROMs
(`.mem`), and executed directly by event-driven Verilog circuits at 640×480 @ 60 Hz.

## The two halves + the bridge

- `verilog/` + `vivado/` — the hardware runtime that runs on the board.
- `tools/` — the Python authoring toolchain + compiler.
- `mem/*.mem` — the compiled ROMs; the neutral hand-off Vivado loads into BRAM.

Pipeline: `stage/*.py → JSON source → JSON decode → mem/*.mem → FPGA`.

## Build / run

```bash
python tools/main/compile_stage_to_json.py   # Python classes -> per-stage JSON
python tools/main/compile_stage_to_mem.py    # JSON -> mem/*.mem (fold + bit-pack)
```

Then open `vivado/ChronoForge.xpr` in Vivado → Generate Bitstream → Program device.
The `.mem` files are already wired into the project, so a content change only needs
the two Python steps + a fresh bitstream.

## Rules of the road

- **Code wins over docs.** Where any document disagrees with the RTL or Python,
  trust the code. `tools/compiler/json_encoders.py` owns ROM bit layouts;
  `verilog/sources/top/topModule.v` owns clocks and resource params.
- **Game authors edit only `tools/main/stage/*.py` and `tools/main/stage_ui/*.py`.**
  Everything else is engine internals.
- **Misspelled-but-real names — use verbatim, don't "fix" blindly:** folders
  `systhesis/`, `interpret_langauge/`; file `verilog/constrains/constains.xdc`;
  JSON key `game_manger`; params `MAXIMUM_*_AMOUT` (missing `N`).
- **Don't treat build junk as source:** `__pycache__/`, `tools/temp/`,
  `vivado/.Xil/`, `vivado/*.zip`.
- **Commit/push only when the user asks.** Git user `Night`; default branch `main`.

## Where to read more

- [`CLAUDE.md`](CLAUDE.md) — full repo map (**start here**).
- [`docs/python-guide.md`](docs/python-guide.md) — authoring API, stages/UI, compiler.
- [`docs/hardware-guide.md`](docs/hardware-guide.md) — Vivado build, config, `.mem` wiring.
- [`docs/hardware-architecture.md`](docs/hardware-architecture.md) — how the hardware works.
