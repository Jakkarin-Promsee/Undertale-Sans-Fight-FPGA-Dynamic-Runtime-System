import json
import os
import tkinter as tk
from tkinter import ttk

# ==================================================
# Directory Setup
# ==================================================
TOOLS_PATH = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STAGE_DATA_DIR = os.path.join(TOOLS_PATH, "source")
STAGE_FILE_PREFIX = "stage"

data = {}
gm = {}
attack_objects = []
platform_objects = []

current_index = 0


# ==================================================
# Load Stage
# ==================================================
def load_stage_from_dropdown(event=None):
    stage_name = stage_var.get()
    if stage_name:
        load_stage(stage_name + ".json")


def load_stage(filename):
    global data, gm, attack_objects, platform_objects

    full_path = os.path.join(STAGE_DATA_DIR, filename)

    with open(full_path, "r") as f:
        data = json.load(f)

    gm = data["game_manger"]
    attack_objects = data["attack_object"]
    platform_objects = data.get("platform_object", [])

    draw_stage()
    update_list()


# ==================================================
# Draw Stage
# ==================================================
def draw_stage():
    canvas.delete("all")

    # Display area
    x1, y1 = gm["display_pos_x1"], gm["display_pos_y1"]
    x2, y2 = gm["display_pos_x2"], gm["display_pos_y2"]

    canvas.create_rectangle(x1, y1, x2, y2, outline="#FFD700", width=2)
    canvas.create_text(x1, y1 - 12, text="Display Area", fill="#FFD700",
                       anchor="sw", font=("Segoe UI", 10, "bold"))

    # Attack objects
    for obj in attack_objects:
        canvas.create_rectangle(obj["pos_x"], obj["pos_y"],
                                obj["pos_x"] + obj["w"], obj["pos_y"] + obj["h"],
                                outline="#ff5555")

    # Platform objects
    for obj in platform_objects:
        canvas.create_rectangle(obj["pos_x"], obj["pos_y"],
                                obj["pos_x"] + obj["w"], obj["pos_y"] + obj["h"],
                                outline="#55ccee")


# ==================================================
# Navigation
# ==================================================
def previous_index():
    try:
        n = int(n_input.get())
    except:
        return
    add_index(-n)


def next_index():
    try:
        n = int(n_input.get())
    except:
        return
    add_index(n)


def add_index(adder):
    global current_index

    total = len(attack_objects) + len(platform_objects)

    current_index += adder
    current_index = max(0, min(current_index, total - 1))

    listbox.selection_clear(0, tk.END)
    listbox.selection_set(current_index)
    listbox.see(current_index)

    highlight_n_objects()


# ==================================================
# Highlight Logic
# ==================================================
def highlight(event=None):
    global current_index

    sel = listbox.curselection()
    if not sel:
        return

    current_index = sel[0]
    highlight_n_objects()


def highlight_n_objects():
    canvas.delete("highlight")

    try:
        n = int(n_input.get())
    except:
        return

    total = len(attack_objects) + len(platform_objects)
    n = min(n, total)

    start = current_index
    end = min(start + n, total)

    # ---- visually show multiple selected rows in Listbox ----
    listbox.selection_clear(0, tk.END)
    for i in range(start, end):
        listbox.selection_set(i)

    # ---- highlight rectangles on canvas ----
    for i in range(start, end):
        if i < len(attack_objects):
            obj = attack_objects[i]
        else:
            obj = platform_objects[i - len(attack_objects)]

        canvas.create_rectangle(
            obj["pos_x"], obj["pos_y"],
            obj["pos_x"] + obj["w"],
            obj["pos_y"] + obj["h"],
            outline="white", width=3, tags="highlight"
        )


# ==================================================
# Update Listbox
# ==================================================
def update_list():
    listbox.delete(0, tk.END)

    for i, obj in enumerate(attack_objects):
        listbox.insert(tk.END, f"Attack {i}: {obj['wait_time']}s / ({obj['pos_x']}, {obj['pos_y']})")

    for i, obj in enumerate(platform_objects):
        listbox.insert(tk.END, f"Platform {i}: {obj['wait_time']}s / ({obj['pos_x']}, {obj['pos_y']})")


# ==================================================
# Stage List
# ==================================================
def get_stage_list():
    files = sorted(
        f for f in os.listdir(STAGE_DATA_DIR)
        if f.startswith(STAGE_FILE_PREFIX) and f.endswith(".json")
    )
    return [f.replace(".json", "") for f in files]


# ==================================================
# Dark Style
# ==================================================
def apply_dark_style(root):
    style = ttk.Style()
    style.theme_use("clam")

    style.configure("TCombobox",
                    fieldbackground="#3c3c3c",
                    background="#2d2d30",
                    foreground="white")

    style.configure("TButton",
                    background="#3a3a3a",
                    foreground="white",
                    padding=6,
                    borderwidth=0)
    style.map("TButton", background=[("active", "#505050")])

    style.configure("TLabel",
                    background="#252526",
                    foreground="white")


# ==================================================
# GUI Setup
# ==================================================
root = tk.Tk()
root.title("ChronoForge Stage Viewer — Dark UI")
root.geometry("1180x650")
root.configure(bg="#1e1e1e")

apply_dark_style(root)

# Left Canvas
canvas = tk.Canvas(root, bg="#2b2b2b", width=720, height=540, highlightthickness=0)
canvas.pack(side="left", padx=15, pady=15)

# Right Panel
right = tk.Frame(root, bg="#252526")
right.pack(side="right", fill="y", padx=10)

# ===== Stage Selector =====
ttk.Label(right, text="Select Stage", font=("Segoe UI", 12, "bold")).pack(pady=(10, 5))

stage_var = tk.StringVar()
stage_combo = ttk.Combobox(right, textvariable=stage_var,
                           values=get_stage_list(), width=25, state="readonly")
stage_combo.pack(pady=5)
stage_combo.bind("<<ComboboxSelected>>", load_stage_from_dropdown)

# ===== Highlight N =====
ttk.Label(right, text="Highlight N", font=("Segoe UI", 11, "bold")).pack(pady=(20, 5))


# Horizontal group
row = tk.Frame(right, bg="#252526")
row.pack(pady=5)

# Input N
n_input = tk.Entry(row, width=6, bg="#3c3c3c", fg="white",
                   insertbackground="white", relief="flat")
n_input.insert(0, "1")
n_input.pack(side="left", padx=5)

# Prev + Next Buttons
prev_btn = ttk.Button(row, text="Previous", command=previous_index)
prev_btn.pack(side="left", padx=5)

next_btn = ttk.Button(row, text="Next", command=next_index)
next_btn.pack(side="left", padx=5)

# ===== Object List =====
ttk.Label(right, text="Objects", font=("Segoe UI", 12, "bold")).pack(pady=(20, 5))

listbox = tk.Listbox(
    right, width=40, height=26,
    bg="#1e1e1e", fg="white",
    selectbackground="#007acc",
    selectmode="extended",
    relief="flat", highlightthickness=0,
    font=("Consolas", 10)
)
listbox.pack(pady=5)

listbox.bind("<<ListboxSelect>>", highlight)

root.mainloop()
