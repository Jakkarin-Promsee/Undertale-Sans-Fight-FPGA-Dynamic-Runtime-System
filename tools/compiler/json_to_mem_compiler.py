import json
import os

# Import all the encoding logic from the library file
from json_encoders import (
    encode_game_manager, encode_attack, encode_platform, 
    bin_to_hex, encode_ui
)

# ====================================================================
# BIT-PACKING COMPILER (json_to_mem_compiler.py)
# Purpose: Reads the unified JSON sources and generates the final 
#          fixed-width hexadecimal (.mem) files for FPGA ROMs.
# ====================================================================


# --------------------------------------------------------------------
# Main Compilation Logic
# --------------------------------------------------------------------
def build_mem_files(isPushingVerilog=True, isHex=True):
    """
    Reads the three unified JSON source files (created by stage_folder.py), 
    encodes their contents, and writes the final .mem files.
    """
    
    tools_path = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    project_path = os.path.dirname(tools_path)

    # --- Path Definitions (Pointing to where stage_folder.py put the files) ---
    UNIFIED_JSON_DIR = os.path.join(tools_path, "json-source-decode")

    if isPushingVerilog :
        MEM_OUTPUT_DIR = os.path.join(project_path, "mem")
    else :
        MEM_OUTPUT_DIR = os.path.join(tools_path, "mem-decode")

    print("--- Status Log ---")
    print(f"Compile: {UNIFIED_JSON_DIR}\*.json")
    print(f"To: {MEM_OUTPUT_DIR}\*.mem")
    print()
    
    # List of all compilation tasks
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
    ]

    print("--- Starting Bit-Packing and ROM Generation ---")
    
    for task in compilation_tasks:
        try:
            # 1. Read the unified JSON source file
            with open(task["json_path"], "r") as f:
                # We expect the unified JSON to have the "decimal_data" root key
                data_list = json.load(f)["decimal_data"]
            
            # 2. Process and write the .mem file
            lines = []
            for idx, entry in enumerate(data_list):
                bitstring = task["encoder"](entry, idx)
                line = bin_to_hex(bitstring) if isHex else bitstring
                lines.append(line)

            # Ensure output folder exists and write the final file
            os.makedirs(os.path.dirname(task["mem_path"]), exist_ok=True)
            with open(task["mem_path"], "w") as f:
                f.write("\n".join(lines))

            print(f"Compiled {len(lines):>4} entries for {task['name']} -> {os.path.basename(task['mem_path'])}")

        except FileNotFoundError:
            print(f"  [SKIPPING] Source file not found for {task['name']} at {task['json_path']}")
        except KeyError as e:
             print(f"  [ERROR] Missing expected key {e} in {task['name']} data.")


# ----------------------------
# Execution
# ----------------------------
if __name__ == "__main__":
    # --- IMPORTANT ---
    # This script assumes source_stage_to_json_compiler.py has already run successfully
    # and has created the three unified JSON files in 'json-source-decode/'.
    build_mem_files(isHex=True)
    
    print("\nCompilation Pipeline Complete. Your .mem files are ready for Vivado.")