> ⚠️ **เอกสารนี้ล้าสมัยแล้ว (OUTDATED).** เนื้อหาด้านล่างเป็นเวอร์ชันเก่าและไม่ตรงกับโค้ดปัจจุบัน
> กรุณาใช้เอกสารภาษาอังกฤษที่อัปเดตแล้วแทน: [README.md](README.md) และโฟลเดอร์ [docs/](docs/)
> (ยังไม่ได้แปลใหม่ — เก็บไว้เพื่ออ้างอิงเท่านั้น)
>
> ⚠️ **This Thai document is OUTDATED** and no longer matches the code. Use the
> English [README.md](README.md) and [docs/](docs/) instead. Kept for reference only.

---

## ภาพรวม

ChronoForge เริ่มจากวงจรนับเลขธรรมดาๆ ที่เอาไว้แมป index ไปใน ROM เพื่อสั่ง event ต่างๆ พอทำไปเรื่อยๆ มันก็โตจนสามารถรันเกมเต็มรูปแบบได้ เราไอ้ออกเเบบทุกอย่างเองหมด - ทั้งวงจร, โครงสร้าง command, compiler, และ interpreter อีกทั้งเราไม่ได้ไปดูด้วยซ้ำว่าคนอื่นเขาทำกันยังไง นี่คือสนามทดลองของพวกเราสำหรับลองนับ command และสังเกตพฤติกรรมฮาร์ดแวร์

ChronoForge คือ pure-hardware game runtime ที่รันบน FPGA ทั้งหมด **ไม่มี CPU** **ไม่มี ISA** **ไม่มี OS** **ไม่มี emulator** มีแค่วงจร event-driven ที่ execute game logic โดยตรงจากข้อมูลที่ประมวลผลแล้วเก็บไว้เป็น hex blocks

เป้าหมายของเราง่ายๆ คือประสิทธิภาพสูงสุด นั่นหมายถึง **LUT usage ต่ำสุด** และ **flip-flops ต่ำสุด** สำหรับแต่ละพฤติกรรม พร้อมกับรักษา **pipeline ที่เร็วที่สุดเท่าที่จะเป็นไปได้**

### ทำไมต้อง ChronoForge?

- **ไม่มี Instruction Overhead:** ไม่เหมือน CPU ที่ต้อง fetch, decode, execute instruction ทีละตัว ChronoForge คือ **Direct-Logic Engine** ทุก game event คือการเปลี่ยน hardware state โดยตรง ตัดปัญหา "bottleneck" ของการทำงานแบบ sequential ทิ้งไปเลย
- **Decentralized Processing:** แต่ละ module มีหน้าที่และ logic เฉพาะของตัวเอง ทำให้กลยุทธ์แบบ event-driven เร็วขึ้นและใช้ resource ได้คุ้มค่ากว่า โดยไม่ต้องพึ่ง master controller ตัวเดียว
- **Massive Parallelism:** game object ทั้งหมด—triggers, colliders, characters—ถูกประมวลผลแบบ parallel ผ่าน hardware pipelines เฉพาะทาง ให้ performance 640x480 @ 60Hz คงที่ไม่ว่าจะมี object เยอะแค่ไหน
- **Hardware-Level Determinism:** ตัด OS กับ CPU interrupts ออกไป ทำให้ทุก frame ถูกคำนวณด้วยความแม่นยำระดับ nanosecond สิ่งที่เห็นใน compiler คือสิ่งที่ hardware execute ทุกครั้ง ไม่มีผิดเพี้ยน
- **The Performance Peak:** ChronoForge คำนวณ pixels สำหรับ 60 dynamic triggers, 30 dynamic colliders และ 80 dynamic characters ภายใน**น้อยกว่า 4 clock cycles** โดยไม่ต้องใช้ Spatial Partitioning—ทั้งหมดอยู่ใน 18k LUTs กับ 7k FFs รองรับได้ถึง 25k attacks/platforms และ 75k character data points ด้วย BRAM แค่ 225 KB

ทุกอย่างออกแบบมาเพื่อบีบ FPGA ให้ได้สุดขีด พร้อมกับยังสร้างง่าย เขียนเกมทั้งเกมด้วย Python classes ไม่ต้องแตะ Verilog สักบรรทัด

<br>

<p align="center" style="text-align: center;">
    <a href="https://youtu.be/yzlUlyLRUwM">
        <img src="docs/images/chonoforge_showcase.png" width="800px" alt="Watch the ChronoForge FPGA Engine Showcase on YouTube">
    </a>
    <br>
    <a href="https://youtu.be/yzlUlyLRUwM">ดู System Demo บน YouTube</a>
</p>

---

## Key Concept — Hardware Timeline Scheduler

ChronoForge ไม่ใช้ CPU, instruction stream หรือ script interpreter  
แต่มันออกแบบมาเพื่อบีบประสิทธิภาพและ resource efficiency สูงสุดบนบอร์ด FPGA ระดับล่าง โดยขับเคลื่อน gameplay ทั้งหมดผ่านสาม hardware timelines อิสระ (event-driven runtimes) ที่ implement เป็น ROM index counters:

- **Attack Timeline**
- **Platform Timeline**
- **Character Timeline**

แต่ละ timeline เดินผ่าน ROM object list ของตัวเองตั้งแต่ index `0` จนถึง terminal header (`FFF*`)  
ทุก object มีทั้ง **spatial data** และ **temporal data** (`wait_time`, `destroy_time`)

แต่ละ timeline มี internal wait counter ของตัวเอง object จะ active ก็ต่อเมื่อ wait counter เป็นศูนย์ หลังจากนั้น timeline ก็จะไปต่อที่ ROM entry ถัดไป

มันสร้าง **fully hardware-driven event scheduler:**

```bash
Runtime Counter -> wait Gate -> Object Index -> ROM -> Add wait -> Runtime Counter
```

เพราะแต่ละ timeline เดินไปคนละทาง objects จึงสามารถ overlap, interleave และ execute พร้อมกันได้ **ไม่มี branching ไม่มี script engine ไม่มี CPU control logic**

**Attack Timeline** ทำหน้าที่เป็น global epoch controller พอ attack index ถึง terminal header เกมทั้งเกมก็จะ reset ทำให้เราสามารถใช้ **null attack objects** เป็น pure time delays ได้ เขียน pauses, waves และ pacing ลงไปใน ROM โดยตรง

**Conceptual View:**

```bash
Attack:    start ------> A0 ------> A1 -------------> A2 -> end -> reset

Platform:  start --> P0 -------------> P1 -----> P2 --> end

Character: start ->  C1 ---> C2 ------------------> C3 --> end
```

แต่ละ object type ถูก implement เป็น **dedicated hardware module** ที่ optimize มาสำหรับหน้าที่ของมัน  
ทั้งสาม timelines ถูกควบคุมด้วย **dynamic register system** ทำให้จำนวน Attack, Platform และ Character objects ที่ active อยู่สามารถ config ได้ตามเกม ตามบอร์ด และตาม resource budget

---

## สิ่งที่เราทำ

- **Hardware Runtime Engine:**
  - ออกแบบและสร้างด้วย Vivado + Verilog
  - ใช้ห้า main runtime pipelines สำหรับ game stage, game ui และ trigger/collider/character object
  - อ่านข้อมูลจาก ROM (ไฟล์ .mem ในรูปแบบ hex)

  - ปรับจำนวน resource ได้:
    - 60 dynamic trigger objects (default)
    - 30 dynamic collider objects (default)
    - 80 dynamic character objects (default)

  - config object pools ได้:
    - วางตำแหน่งอิสระ
    - ขนาดกำหนดเอง
    - 32 ระดับความเร็ว
    - 8 ทิศทางการเคลื่อนที่
    - Wait time
    - Destroy time

  - config player pools ได้:
    - ตำแหน่งและขนาดแสดงผลอิสระ
    - ขนาด hitbox ของ player กำหนดเอง
    - เปิด/ปิด Gravity
    - HP และความไวต่อความเสียหาย
    - เปิด/ปิด HP bar พร้อมตำแหน่ง

<br>

- **Compiler:**
  - ใช้ json เป็น Skeleton structure เก็บข้อมูลทุกอย่างสำหรับแต่ละ runtime
  - ใช้ python script compile json เป็นไฟล์ mem ในรูปแบบ hex สำหรับ hardware runtime structure
  - ข้อมูลทั้งหมดจะถูก preprocessing ฝั่ง compiler แยกออกเป็น 5 ไฟล์ mem ที่พร้อมใช้งานฝั่ง hardware ได้ทันที

<br>

- **Interpreter/Game engine:**
  - ใช้ python class interpret แต่ละประเภทข้อมูล (python class -> json -> hex)
    - Game Stage: `EntireGame`, `GameManager`, `GameStage`, `AttackObject` และ `PlatformObject`
    - Game Stage UI: `EntireGameUI`, `GameUIStage`, `GameUI` และ `CharacterObject`
  - ใช้ python code จัดการ file structure ให้อ่านและแก้ไขง่าย

```bash
    stage/
    ├── stage00.json
    ├── stage01.json
    └── ...
```

```bash
    stage_ui/
    ├── stage_ui_00.json
    ├── stage_ui_02.json
    └── ...
```

- ใช้ python list ธรรมดาเก็บแต่ละ element และใช้ `for` loop สร้าง item ซ้ำๆ ได้ง่ายๆ

```py
    # ตัวอย่าง stage_01.json
    import sys, os
    sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..')))
    from interpret_langauge.game_class import GameStage, GameManager, AttackObject, PlatformObject

    def stage():
        stage = GameStage()

        # Game Manager Configuration (ไม่แสดง player)
        stage.game_manager = GameManager(stage=1, wait_time=1, gravity_direction=0, display_pos_x1=0, display_pos_y1=0, display_pos_x2=0, display_pos_y2=0)

        # Common Parameters
        ATTACK_SIZE = 20
        ATTACK_GAP = 30
        ATTACK_X = 85
        ATTACK_Y = 140

        # Initial Delay (2 วินาที)
        stage.attack_objects.append(
            AttackObject(type=0, colider_type=0, movement_direction=2, speed=0, pos_x=0, pos_y=0, w=0, h=0, wait_time=2, destroy_time=0, destroy_trigger=2, )
        )

        # Helper: สร้าง 10 object ในแถว
        def generate_row(attack_y):
            stage.attack_objects.extend([
                    AttackObject(type=0, colider_type=0, movement_direction=0, speed=0, pos_x=ATTACK_X + (ATTACK_SIZE + ATTACK_GAP)*i, pos_y=attack_y, w=ATTACK_SIZE, h=ATTACK_SIZE, wait_time=0, destroy_time=4, destroy_trigger=2, )
                    for i in range(10)
            ])

        # สร้างคอลัมน์แบบซ้ำ
        for i in range(6):
            generate_row(ATTACK_Y + (ATTACK_SIZE+ATTACK_GAP)*i)

        # Last Delay (5 วินาที)
        stage.attack_objects.append(
            AttackObject(type=0, colider_type=0, movement_direction=2, speed=0, pos_x=0, pos_y=0, w=0, h=0, wait_time=7, destroy_time=0, destroy_trigger=2, )
        )

        # Platform Placeholder (ไม่เคลื่อนที่)
        stage.platform_objects.append(
            PlatformObject(movement_direction=2, speed=0, pos_x=0, pos_y=0, w=0, h=0, wait_time=0, destroy_time=0, destroy_trigger=2)
        )

        return stage
```

```python
    # ตัวอย่าง stage_ui_01.json
    import sys, os
    sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..')))
    from interpret_langauge.game_class import GameUIStage, GameUI, CharacterObject


    def stage():
        stage = GameUIStage()

        # Game UI Configuration (ไม่แสดง player)
        stage.game_ui = GameUI(show_healt_text=1, reset_character=1, transparent_out_screen_display=0, healt_current=96, healt_max=96, healt_bar_pos_x=190, healt_bar_pos_y=400, healt_bar_w=120, healt_bar_h=20, healt_bar_sensitivity=0.04, wait_time=1000)

        # เขียน string เป็น character object แต่ละตัว
        stage.character_objects.extend([
            CharacterObject(167 + (center_data.CHARACTER_W + center_data.GAP) * i, 74, ch)
            for i, ch in enumerate("GAMEPLAY SHOWCASE")
            if ch != " "
        ])

        return stage
```

- มี python gui ให้ visualize ตำแหน่ง object ทั้งหมด ทดสอบก่อน upload ขึ้นบอร์ด
<p align="center" style="text-align: center;">
    <img src="docs\images\chonoforge_python_gui2.png" alt="Early Convergence Comparison" width="800px">
</p>

---

## เราใช้ resource ไปเท่าไหร่

- **Current Board Utilization (Basys3):**

  | Resource | Utilization | Available | Board Usage % |
  | :------- | :---------- | :-------- | :------------ |
  | LUT      | 18015       | 20800     | 87%           |
  | FF       | 7196        | 41600     | 17%           |
  | BUFG     | 6           | 32        | 19%           |

  (Default: 60 dynamic attack, 30 dynamic platform และ 80 dynamic character)

<br>

- **ความจุข้อมูล ROM:**

  | ROM Type         | Bytes/Object | จำนวนสูงสุด (Basys3 BRAM) |
  | :--------------- | :----------- | :------------------------ |
  | Attack Object    | 9 bytes      | 25,000 attacks            |
  | Platform Object  | 8 bytes      | 28,125 platforms          |
  | Character Object | 3 bytes      | 75,000 characters         |

  (ความจุ BRAM ของ Basys3: 1.8 Mb ≈ 225 KB รวม)

---

## ปัญหาที่เจอ

1. **The 4-Clock Pixel Deadline**
   clock หลักของเรารันที่ 100 MHz แต่ VGA clock 25 MHz (640x480 @ 60 Hz) เหลือเวลาแค่ **4 cycles ต่อ pixel** สำหรับประมวลผล พอมี workload 100 triggers, 50 colliders และ 100 characters multiplexer chains หรือ logic แบบ `if-else` ธรรมดามันช้าไป ตอนแรกคิดจะใช้ **Spatial Partitioning** แต่ hardware structure มันซับซ้อนเกินไปที่จะเชื่อมกับ event-driven runtime ของเรา วิธีแก้คือใช้ **Bitwise OR Composition** แบบ "บรูทัล"—รวม pixel signals ของ object ทั้งหมดทันทีเพื่อให้ได้ compute time เร็วสุด
   <br>

2. **Event-Driven Runtime Synchronization**
   แผนคือแยก runtimes ตามหน้าที่แล้วเชื่อมกันผ่าน bridge clock (`clk_calculation`) ฟังดูง่ายในทฤษฎี แต่ปฏิบัติมันโหดมาก เพราะแต่ละ runtime มี "ความคิดของมันเอง" กับ logic ของมัน ทำให้ communication timelines ไม่เป็น linear เราแก้โดยลด redundancy ดึง decision-making ทั้งหมดมาอยู่ใน **สาม main runtimes** และทำให้ตัวอื่นๆ เหลือแค่ "no-thought" executors ที่รอรับคำสั่งทำตาม
   <br>

3. **Instance Spawning Lag (The Millisecond Lie)**
   ทดสอบบน hardware จริงถึงรู้ว่า timer 100 Hz (0.01s) มันไม่พอ กลยุทธ์ synchronization ของเราต้อง check clock สามครั้ง รวมกันได้ delay 0.03s ที่ผู้เล่นรู้สึกได้ชัด เราเลยเพิ่ม timer เป็น **1 kHz** หมายความว่า signal `centi_second` ตอนนี้มันนับเป็น **milliseconds** จริงๆ แล้ว เราเก็บชื่อไว้เพื่อไม่ให้ logic พัง แต่พฤติกรราถูกต้องแล้ว
   <br>

4. **Compiler and Interpreter Layer**
   ไม่มีประสบการณ์เรื่องนี้เลย ต้องคิดเองว่าจะเชื่อม code ที่คนอ่านได้กับ hex data ที่ประมวลผลแล้วยังไง solution ที่ได้ออกมาเป็น **Meaning Stack**:  
   `Machine Code → JSON Decode → JSON Source → Python Class → Workspace Environment`  
   แต่ละ layer เพิ่ม intention ขณะที่ลดความกำกวม ทำให้ user สร้างเกมได้สะดวกโดยไม่ต้องแตะ hardware
   <br>

5. **A Tangle Too Large to Visualize**
   ปัญหาใหญ่สุดคือโปรเจกต์โตจนกลายเป็นวงจรยักษ์ที่พันกันยุ่งเหยิงผ่านการลองผิดลองถูก เพราะเราขาดประสบการณ์ features ก็ถูกเพิ่มไปเรื่อยๆ จนมันใช้งานได้ ผลก็คือ naming rules กับ coding styles ไม่สม่ำเสมอข้ามหลาย modules เรา refactor บ่อยๆ แต่บางส่วนของ system ยังยุ่งอยู่ดี section นี้มีไว้บันทึกความจริง ไม่ได้ตั้งใจปิดบัง
   <br>
