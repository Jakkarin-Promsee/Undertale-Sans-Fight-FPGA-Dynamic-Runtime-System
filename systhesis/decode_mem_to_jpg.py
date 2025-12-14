from PIL import Image
import os

# ---------------- CONFIG ----------------
IMG_SIZE = 17
INPUT_MEM = "font_data.mem"
OUTPUT_DIR = "decoded_jpg"

WHITE = 255
BLACK = 0

CHAR_LIST = (
    [chr(c) for c in range(ord('a'), ord('z') + 1)] +
    [str(i) for i in range(11)]
)
# ---------------------------------------


def bits_to_image(bits, out_path):
    img = Image.new("L", (IMG_SIZE, IMG_SIZE))

    for y in range(IMG_SIZE):
        for x in range(IMG_SIZE):
            img.putpixel(
                (x, y),
                BLACK if bits[y][x] == '1' else WHITE
            )

    img.save(out_path)


def main():
    main_path = os.path.dirname(os.path.abspath(__file__))
    project_path = os.path.dirname(main_path)

    mem_path = os.path.join(project_path, "mem", INPUT_MEM)
    out_dir = os.path.join(main_path, OUTPUT_DIR)

    os.makedirs(out_dir, exist_ok=True)  # 🔑 REQUIRED

    with open(mem_path, "r") as f:
        lines = [line.strip() for line in f if line.strip()]

    expected_lines = len(CHAR_LIST) * IMG_SIZE
    if len(lines) != expected_lines:
        raise ValueError(
            f"Expected {expected_lines} lines, got {len(lines)}"
        )

    idx = 0
    for ch in CHAR_LIST:
        bits = lines[idx:idx + IMG_SIZE]
        idx += IMG_SIZE

        for row in bits:
            if len(row) != IMG_SIZE or not set(row) <= {"0", "1"}:
                raise ValueError("Invalid .mem format")

        out_file = os.path.join(out_dir, f"{ch}.jpg")
        bits_to_image(bits, out_file)

    print(f"Decoded {len(CHAR_LIST)} characters into '{OUTPUT_DIR}/'")


if __name__ == "__main__":
    main()
