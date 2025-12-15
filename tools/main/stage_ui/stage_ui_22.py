import sys, os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..')))
from interpret_langauge.game_class import GameUIStage, GameUI, CharacterObject

from main.stage_ui import center_data

def stage():
    stage = GameUIStage()

    stage.game_ui = GameUI(
        show_healt_text=0,
        reset_character=1,
        transparent_out_screen_display=1,
        healt_current=0,
        healt_max=96,
        healt_bar_pos_x=260,
        healt_bar_pos_y=400,
        healt_bar_w=120,
        healt_bar_h=20,
        healt_bar_sensitivity=0.04,
        wait_time=4
    )

    stage.character_objects.extend([
        CharacterObject(32 + (center_data.CHARACTER_W + center_data.GAP) * i, 74, ch)
        for i, ch in enumerate("SUPPORT PLAYER HELTH BAR")
        if ch != " "            
    ])

    stage.character_objects.extend([
        CharacterObject(158 + (center_data.CHARACTER_W + center_data.GAP) * i, 102, ch)
        for i, ch in enumerate("AND HELTH DIGIT STATUS")
        if ch != " "
    ])

    return stage