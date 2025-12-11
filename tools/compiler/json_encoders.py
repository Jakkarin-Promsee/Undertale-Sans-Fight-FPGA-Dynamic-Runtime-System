# ====================================================================
# CHRONOFORGE ENCODER LIBRARY (json_encoders.py)
# Version: 1.0
# Purpose: Defines the fixed-width bit structure and scaling rules 
#          for all game object ROMs used by the ChronoForge FPGA Engine.
# ====================================================================

# --------------------------------------------------------------------
# 1. Bit-Packing Helper (The most crucial function)
# --------------------------------------------------------------------
def pack_bits(value, width, entry_index=None, field_name=None):
    """
    Ensures an integer `value` is correctly sized to exactly `width` bits
    and returns it as a binary string. This function enforces hardware constraints.
    """
    
    value = int(value)

    # Check for Overflow: Is the value too large for the specified bit width?
    # e.g., If width=8, max value is 255. If value > 255, it's an error.
    if value >= (1 << width):
        if entry_index is not None and field_name is not None:
            print(f"[OVERFLOW WARNING] Entry #{entry_index}, Field '{field_name}': "
                  f"Value={value} is too large. Max width={width} bits. "
                  f"The value was truncated.")
    
    # Mask the value to force it into the correct width (truncates any extra bits)
    masked = value & ((1 << width) - 1)
    
    # Convert the masked integer to a binary string, padded with leading zeros
    # e.g., format(5, '04b') returns "0101"
    return format(masked, f'0{width}b')


# --------------------------------------------------------------------
# 2. Game Manager Encoder (Stage Flow ROM Specification)
# Total Bit Width: 74 bits
# --------------------------------------------------------------------
def encode_game_manager(entry, index=None):
    """ Assembles the bitstring for one Game Manager entry (one stage sequence). """
    bits = ""
    
    # 8 bits: Unique Stage ID
    bits += pack_bits(entry["stage"], 8, index, "stage")
    
    # 10 bits: How many Attack records follow in the Attack ROM
    bits += pack_bits(entry["attack_amount"], 10, index, "attack_amount")
    
    # 10 bits: How many Platform records follow in the Platform ROM
    bits += pack_bits(entry["platform_amount"], 10, index, "platform_amount")
    
    # 3 bits: Direction of gravity vector (8-way direction codes)
    bits += pack_bits(entry["gravity_direction"], 3, index, "gravity_direction")
    
    # 8 bits x 4: Viewport/Screen Corners (Scaled down by 4)
    # The JSON input (e.g., 500) is divided by 4 to fit into 8 bits for efficiency.
    bits += pack_bits(int(entry["display_pos_x1"]/4), 8, index, "display_pos_x1")
    bits += pack_bits(int(entry["display_pos_y1"]/4), 8, index, "display_pos_y1")
    bits += pack_bits(int(entry["display_pos_x2"]/4), 8, index, "display_pos_x2")
    bits += pack_bits(int(entry["display_pos_y2"]/4), 8, index, "display_pos_y2")
    
    # 8 bits: Wait time before advancing stage (converted to 100Hz ticks)
    # e.g., Input 2 seconds -> stored as 20 (2 * 10) ticks.
    bits += pack_bits(entry["wait_time"]*10, 8, index, "wait_time")
    
    # 1 bit: Unused filler bit to align the data word
    bits += pack_bits(entry["free(unused)"], 1, index, "free(unused)")
    
    return bits


# --------------------------------------------------------------------
# 3. Attack Object Encoder (Trigger ROM Specification)
# Total Bit Width: 86 bits
# --------------------------------------------------------------------
def encode_attack(entry, index=None):
    """ Assembles the bitstring for one Attack object entry. """
    bits = ""
    
    # 5 bits: Attack Type ID (e.g., damage profile, animation)
    bits += pack_bits(entry["type"], 5, index, "type")
    
    # 2 bits: Shape of the collider/trigger box
    bits += pack_bits(entry["colider_type"], 2, index, "colider_type")
    
    # 3 bits: Initial movement direction
    bits += pack_bits(entry["movement_direction"], 3, index, "movement_direction")
    
    # 5 bits: Speed level (32 levels max)
    bits += pack_bits(entry["speed"], 5, index, "speed")
    
    # 8 bits x 4: Position (x, y) and Dimension (w, h) - All scaled by 4
    bits += pack_bits(int(entry["pos_x"]/4), 8, index, "pos_x")
    bits += pack_bits(int(entry["pos_y"]/4), 8, index, "pos_y")
    bits += pack_bits(int(entry["w"]/4), 8, index, "w")
    bits += pack_bits(int(entry["h"]/4), 8, index, "h")
    
    # 8 bits: Delay before this object spawns (converted to 100Hz ticks)
    bits += pack_bits(entry["wait_time"]*10, 8, index, "wait_time")
    
    # 8 bits: Lifetime before forced destruction (in 100Hz ticks)
    bits += pack_bits(entry["destroy_time"], 8, index, "destroy_time")
    
    # 2 bits: Condition that triggers object removal (e.g., hit player, time out)
    bits += pack_bits(entry["destroy_trigger"], 2, index, "destroy_trigger")
    
    # 7 bits: Unused filler
    bits += pack_bits(entry["free(unused)"], 7, index, "free(unused)")

    return bits


# --------------------------------------------------------------------
# 4. Platform Object Encoder (Collider ROM Specification)
# Total Bit Width: 71 bits
# --------------------------------------------------------------------
def encode_platform(entry, index=None):
    """ Assembles the bitstring for one Platform object entry. """
    bits = ""
    
    # 3 bits: Movement direction
    bits += pack_bits(entry["movement_direction"], 3, index, "movement_direction")
    
    # 5 bits: Speed level
    bits += pack_bits(entry["speed"], 5, index, "speed")
    
    # 8 bits x 4: Position (x, y) and Dimension (w, h) - All scaled by 4
    bits += pack_bits(int(entry["pos_x"]/4), 8, index, "pos_x")
    bits += pack_bits(int(entry["pos_y"]/4), 8, index, "pos_y")
    bits += pack_bits(int(entry["w"]/4), 8, index, "w")
    bits += pack_bits(int(entry["h"]/4), 8, index, "h")
    
    # 8 bits: Delay before this object spawns (converted to 100Hz ticks)
    bits += pack_bits(entry["wait_time"]*10, 8, index, "wait_time")
    
    # 8 bits: Lifetime before forced destruction (in 100Hz ticks)
    bits += pack_bits(entry["destroy_time"], 8, index, "destroy_time")
    
    # 2 bits: Condition that triggers object removal
    bits += pack_bits(entry["destroy_trigger"], 2, index, "destroy_trigger")
    
    # 6 bits: Unused filler
    bits += pack_bits(entry["free(unused)"], 6, index, "free(unused)")
    
    return bits


# --------------------------------------------------------------------
# 5. Hex Conversion (Utility)
# --------------------------------------------------------------------
def bin_to_hex(bitstring):
    """ Converts a binary string into a padded hexadecimal string. """
    # Calculate required length for hex (round up to the nearest multiple of 4 bits)
    hex_len = (len(bitstring) + 3) // 4 
    
    # Convert binary to integer, then format as hex with leading zeros
    return format(int(bitstring, 2), f'0{hex_len}X')