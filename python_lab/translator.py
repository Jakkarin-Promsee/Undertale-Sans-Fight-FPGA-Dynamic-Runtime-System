import json
import os

# ----------------------------
# Bit pack helper with overflow check
# ----------------------------
def pack_bits(value, width, entry_index=None, field_name=None):
    """
    Force integer `value` into exactly `width` bits.
    Reverse bit order (LSB to RSB) before returning.
    """
    if value >= (1 << width):
        if entry_index is not None and field_name is not None:
            print(f"[OVERFLOW] Entry #{entry_index}, Field '{field_name}': "
                  f"value={value}, width={width}, needs {value.bit_length()} bits")
    masked = value & ((1 << width) - 1)
    # bitstr = format(masked, f'0{width}b')
    return format(masked, f'0{width}b')
    # Reverse bits for LSB→RSB
    # return bitstr[::-1]


# ----------------------------
# Encode Game Manager Data
# ----------------------------
def encode_game_manager(entry, index=None):
    bits = ""
    bits += pack_bits(entry["stage"], 8, index, "stage")
    bits += pack_bits(entry["attack_amount"], 10, index, "attack_amount")
    bits += pack_bits(entry["platform_amount"], 10, index, "platform_amount")
    bits += pack_bits(entry["free(unused)"], 4, index, "free(unused)")
    bits += pack_bits(entry["wait_time"]*10, 8, index, "wait_time")
    return bits


# ----------------------------
# Encode Attack Object Data
# ----------------------------
def encode_attack(entry, index=None):
    bits = ""
    bits += pack_bits(entry["type"], 5, index, "type")
    bits += pack_bits(entry["colider_type"], 2, index, "colider_type")
    bits += pack_bits(entry["movement_direction"], 3, index, "movement_direction")
    bits += pack_bits(entry["speed"], 5, index, "speed")
    bits += pack_bits(entry["free(unused)"], 1, index, "free(unused)")
    bits += pack_bits(int(entry["pos_x"]/4), 8, index, "pos_x")
    bits += pack_bits(int(entry["pos_y"]/4), 8, index, "pos_y")
    bits += pack_bits(int(entry["w"]/4), 8, index, "w")
    bits += pack_bits(int(entry["h"]/4), 8, index, "h")
    bits += pack_bits(entry["time"]*10, 8, index, "time")
    return bits


# ----------------------------
# Encode Platform Object Data
# ----------------------------
def encode_platform(entry, index=None):
    bits = ""
    bits += pack_bits(entry["movement_direction"], 3, index, "movement_direction")
    bits += pack_bits(entry["speed"], 5, index, "speed")
    bits += pack_bits(int(entry["pos_x"]/4), 8, index, "pos_x")
    bits += pack_bits(int(entry["pos_y"]/4), 8, index, "pos_y")
    bits += pack_bits(int(entry["w"]/4), 8, index, "w")
    bits += pack_bits(int(entry["h"]/4), 8, index, "h")
    bits += pack_bits(entry["time"]*10, 8, index, "time")
    return bits


# ----------------------------
# Convert binary string → hex (optional)
# ----------------------------
def bin_to_hex(bitstring):
    hex_len = (len(bitstring) + 3) // 4  # Round up to full hex char
    return format(int(bitstring, 2), f'0{hex_len}X')


# ----------------------------
# Main builder
# ----------------------------
def build_mem(input_json_path, output_mem_path, encoder, hex_output=False):
    with open(input_json_path, "r") as f:
        data = json.load(f)["decimal_data"]

    lines = []
    for idx, entry in enumerate(data):
        bitstring = encoder(entry, idx)
        line = bin_to_hex(bitstring) if hex_output else bitstring
        lines.append(line)

    os.makedirs(os.path.dirname(output_mem_path), exist_ok=True)
    with open(output_mem_path, "w") as f:
        f.write("\n".join(lines))

    print(f"Written {len(lines)} entries → {output_mem_path}")


# ----------------------------
# Usage
# ----------------------------
if __name__ == "__main__":
    base_python_lab = os.path.dirname(os.path.abspath(__file__))
    base_Uppertale = os.path.dirname(base_python_lab)

    isPushingVerilog = True
    isHex = True  # 0 = binary output, 1 = hex output

    base_game_manager_path = os.path.join(base_python_lab, "output","game_manager.mem")
    verilog_game_manager_path = os.path.join(base_Uppertale, "UpperTale.srcs", "sources_1", "new","game_manager.mem")

    base_attack_object_path = os.path.join(base_python_lab, "output","attack_object.mem")
    verilog_attack_object_path = os.path.join(base_Uppertale, "UpperTale.srcs", "sources_1", "new","attack_object.mem")

    base_platform_object_path = os.path.join(base_python_lab, "output","platform_object.mem")
    verilog_platform_object_path = os.path.join(base_Uppertale, "UpperTale.srcs", "sources_1", "new","platform_object.mem")

    # Build Game Manager .mem
    build_mem(
        os.path.join(base_python_lab, "data", "game_manager.json"),
        verilog_game_manager_path if isPushingVerilog else base_game_manager_path,
        encode_game_manager,
        hex_output=isHex
    )

    # Build Attack Objects .mem
    build_mem(
        os.path.join(base_python_lab, "data", "attack_object.json"),
        verilog_attack_object_path if isPushingVerilog else base_attack_object_path,
        encode_attack,
        hex_output=isHex
    )

    # Build Platform Objects .mem
    build_mem(
        os.path.join(base_python_lab, "data", "platform_object.json"),
        verilog_platform_object_path if isPushingVerilog else base_platform_object_path,
        encode_platform,
        hex_output=isHex
    )
