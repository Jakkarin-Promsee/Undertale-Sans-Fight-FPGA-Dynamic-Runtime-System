from PIL import Image
import os

# ---------------- CONFIG ----------------
IMG_SIZE = 17
THRESHOLD = 128           # < threshold = black (1)
OUTPUT_FILE = "font_data.mem"

CHAR_LIST = (
    [chr(c) for c in range(ord('a'), ord('z') + 1)] +
    [str(i) for i in range(11)]
)
# ---------------------------------------


def image_to_bits(img_path):
    img = Image.open(img_path).convert("L")  # grayscale
    img = img.resize((IMG_SIZE, IMG_SIZE))   # safety

    bits = []
    for y in range(IMG_SIZE):
        row = ""
        for x in range(IMG_SIZE):
            pixel = img.getpixel((x, y))
            row += '1' if pixel < THRESHOLD else '0'
        bits.append(row)

    return bits


def main():
    main_path = os.path.dirname(os.path.abspath(__file__))
    project_path = os.path.dirname(main_path)

    with open(os.path.join(project_path, "mem", OUTPUT_FILE), "w") as f:
        for ch in CHAR_LIST:
            filename =   os.path.join(main_path, "17x17_font_data", f"{ch}.jpg")

            if not os.path.exists(filename):
                raise FileNotFoundError(filename)

            bits = image_to_bits(filename)

            # # Optional comment (Vivado ignores it)
            # f.write(f"// {ch}\n")

            for row in bits:
                f.write(row + "\n")

    print(f"Generated {OUTPUT_FILE} ({len(CHAR_LIST)} chars)")


if __name__ == "__main__":
    main()