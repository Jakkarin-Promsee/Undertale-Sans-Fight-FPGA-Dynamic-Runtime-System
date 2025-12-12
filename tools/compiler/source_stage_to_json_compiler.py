import json
import os
import glob

# ====================================================================
# STAGE FOLDER SCRIPT (source_stage_to_json_compiler.py)
# Purpose: Reads N individual stage files and folds them into three 
#          master sequential JSON files for compilation.
# ====================================================================

# TOOLS_PATH is now the 'tools' directory (e.g., ChronoForge-FPGA-Engine/tools)
TOOLS_PATH = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Input: Directory containing sequentially named stage JSON files (e.g., stage00.json)
STAGE_DATA_DIR = os.path.join(TOOLS_PATH, "source")
STAGE_FILE_PATTERN = "stage*.json"

# Output: Directory for the unified JSON files
UNIFIED_JSON_DIR = os.path.join(TOOLS_PATH, "json-source-decode") 

GAME_MANAGER_OUT = os.path.join(UNIFIED_JSON_DIR, "game_manager.json")
ATTACK_OUT = os.path.join(UNIFIED_JSON_DIR, "attack_object.json")
PLATFORM_OUT = os.path.join(UNIFIED_JSON_DIR, "platform_object.json")

# --------------------------------------------------------------------
# Core Folding Logic
# --------------------------------------------------------------------
def fold_stages_to_json():
    """
    1. Finds and sorts all stage JSON files.
    2. Folds data into three master lists.
    3. Writes the three unified JSON files to the output directory.
    """
    print(f"--- Starting Stage Folding Process ---")
    
    # 1. Initialize Master Data Lists
    game_manager_master = []
    attack_master = []
    platform_master = []
    
    # 2. Find and Sort Stage Files
    stage_files = glob.glob(os.path.join(STAGE_DATA_DIR, STAGE_FILE_PATTERN))
    stage_files.sort() 
    
    if not stage_files:
        print(f"ERROR: No stage files found in {STAGE_DATA_DIR}. Please check the directory and file naming (stage00.json).")
        return False

    print(f"[Found {len(stage_files)} stages to process]")

    # 3. Process and Fold Stages
    for idx, filepath in enumerate(stage_files):
        filename = os.path.basename(filepath)
        
        try:
            with open(filepath, 'r') as f:
                stage_data = json.load(f)
        except json.JSONDecodeError as e:
            print(f"CRITICAL ERROR: Invalid JSON in {filename}: {e}")
            continue

        # Append the single game manager entry for this stage
        if "game_manger" in stage_data:
            game_manager_master.append(stage_data["game_manger"])
        
        # Extend the master list with all attacks from this stage
        if "attack_object" in stage_data and isinstance(stage_data["attack_object"], list):
            attack_master.extend(stage_data["attack_object"])
        
        # Extend the master list with all platforms from this stage
        if "platform_object" in stage_data and isinstance(stage_data["platform_object"], list):
            platform_master.extend(stage_data["platform_object"])

    # 4. Write the Three Unified JSON Files
    os.makedirs(UNIFIED_JSON_DIR, exist_ok=True)
    
    # Structure data for output (must have the "decimal_data" root key)
    output_data = {
        GAME_MANAGER_OUT: {"decimal_data": game_manager_master},
        ATTACK_OUT:       {"decimal_data": attack_master},
        PLATFORM_OUT:     {"decimal_data": platform_master},
    }

    print("\n--- Writing Unified JSON Sources ---")
    
    for path, data in output_data.items():
        with open(path, 'w') as f:
            json.dump(data, f, indent=4)
        print(f"Wrote {len(data['decimal_data']):>4} entries to: {os.path.basename(path)}")
        
    print("--- Folding Complete! ---")
    return True

# ----------------------------
# Execution
# ----------------------------
if __name__ == "__main__":
    if fold_stages_to_json():
        print("\nNext Step: Run 'json_to_mem_compiler.py' to generate the final .mem files.")