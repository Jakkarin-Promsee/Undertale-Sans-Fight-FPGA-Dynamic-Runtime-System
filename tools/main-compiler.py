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
    bits += pack_bits(entry["gravity_direction"], 3, index, "gravity_direction")
    bits += pack_bits(int(entry["display_pos_x1"]/4), 8, index, "display_pos_x1")
    bits += pack_bits(int(entry["display_pos_y1"]/4), 8, index, "display_pos_y1")
    bits += pack_bits(int(entry["display_pos_x2"]/4), 8, index, "display_pos_x2")
    bits += pack_bits(int(entry["display_pos_y2"]/4), 8, index, "display_pos_y2")
    bits += pack_bits(entry["wait_time"]*10, 8, index, "wait_time")
    bits += pack_bits(entry["free(unused)"], 1, index, "free(unused)")
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
    bits += pack_bits(int(entry["pos_x"]/4), 8, index, "pos_x")
    bits += pack_bits(int(entry["pos_y"]/4), 8, index, "pos_y")
    bits += pack_bits(int(entry["w"]/4), 8, index, "w")
    bits += pack_bits(int(entry["h"]/4), 8, index, "h")
    bits += pack_bits(entry["wait_time"]*10, 8, index, "wait_time")
    bits += pack_bits(entry["destroy_time"], 8, index, "destroy_time")
    bits += pack_bits(entry["destroy_trigger"], 2, index, "destroy_trigger")
    bits += pack_bits(entry["free(unused)"], 7, index, "free(unused)")

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
    bits += pack_bits(entry["wait_time"]*10, 8, index, "wait_time")
    bits += pack_bits(entry["destroy_time"], 8, index, "destroy_time")
    bits += pack_bits(entry["destroy_trigger"], 2, index, "destroy_trigger")
    bits += pack_bits(entry["free(unused)"], 6, index, "free(unused)")
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
    tools_path = os.path.dirname(os.path.abspath(__file__))
    project_path = os.path.dirname(tools_path)

    isPushingVerilog = True
    isHex = True  # 0 = binary output, 1 = hex output

    build_path = []

    game_manager_json_path = os.path.join(tools_path, "json-source","game_manager.json")
    game_manager_mem_test_path = os.path.join(tools_path, "mem-decode","game_manager.mem")
    game_manager_mem_vivado_path = os.path.join(project_path, "mem", "game_manager.mem")
    build_path.append([game_manager_json_path, game_manager_mem_test_path, game_manager_mem_vivado_path, encode_game_manager])

    attack_object_json_path = os.path.join(tools_path, "json-source","attack_object.json")
    attack_object_mem_test_path = os.path.join(tools_path, "mem-decode","attack_object.mem")
    attack_object_mem_vivado_path = os.path.join(project_path, "mem","attack_object.mem")
    build_path.append([attack_object_json_path, attack_object_mem_test_path, attack_object_mem_vivado_path, encode_attack])

    platform_object_json_path = os.path.join(tools_path, "json-source","platform_object.json")
    platform_object_mem_test_path = os.path.join(tools_path, "mem-decode","platform_object.mem")
    platform_object_mem_vivado_path = os.path.join(project_path, "mem","platform_object.mem")
    build_path.append([platform_object_json_path, platform_object_mem_test_path,platform_object_mem_vivado_path, encode_platform])


    for source, test, vivado, encode in build_path:
        build_mem(
            source,
            vivado if isPushingVerilog else test,
            encode,
            hex_output=isHex
        )

