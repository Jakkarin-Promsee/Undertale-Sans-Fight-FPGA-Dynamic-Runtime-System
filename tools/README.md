# tools/ — ChronoForge Python toolchain

> ⚠️ **This file is deprecated.** Its old compiler/data-format notes drifted from
> the code (wrong bit widths, paths, and field semantics) and have been replaced.
>
> The authoritative documentation now lives in:
>
> - **[../docs/python-guide.md](../docs/python-guide.md)** — authoring API, writing
>   stages/UI, the full compiler pipeline & implementation, and font tooling.
> - **[../docs/hardware-guide.md](../docs/hardware-guide.md)** — how the compiled
>   `.mem` ROMs wire into Vivado.

## What's in here (quick map)

```
tools/
├── main/                 ← Game-author workspace (edit here)
│   ├── stage/            ← stage_*.py : attack + platform objects
│   ├── stage_ui/         ← stage_ui_*.py : UI config + on-screen text
│   ├── compile_stage_to_json.py   ← Python classes → per-stage JSON
│   ├── compile_stage_to_mem.py    ← JSON → .mem ROMs (runs the compiler)
│   └── open_game_engine_gui.py    ← launch the stage previewer
├── interpret_langauge/   ← game_class.py : the authoring class API
├── compiler/             ← main_compiler.py + json_encoders.py (bit packing)
├── python_gui/           ← stage_viewer.py (tkinter previewer)
└── json_stage_source/, json_stage_ui_source/, json-source-decode/  ← generated
```

See **[../docs/python-guide.md](../docs/python-guide.md)** for the full picture.
