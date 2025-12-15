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
        healt_max=0,
        healt_bar_pos_x=0,
        healt_bar_pos_y=0,
        healt_bar_w=0,
        healt_bar_h=0,
        healt_bar_sensitivity=0.04,
        wait_time=8
    )

    stage.character_objects.extend([
        CharacterObject(113 + (center_data.CHARACTER_W + center_data.GAP) * i, 218, ch)
        for i, ch in enumerate("SUPPORT 79 DYNAMIC TEXT")
        if ch != " "            
    ])

    stage.character_objects.extend([
        CharacterObject(140 + (center_data.CHARACTER_W + center_data.GAP) * i, 245, ch)
        for i, ch in enumerate("MAXIMUM IN ONE FRAME")
        if ch != " "
    ])

    stage.character_objects.extend([
        CharacterObject(6 + (center_data.CHARACTER_W + center_data.GAP) * i, 280, ch)
        for i, ch in enumerate("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        if ch != " "
    ])

    stage.character_objects.extend([
        CharacterObject(141 + (center_data.CHARACTER_W + center_data.GAP) * i, 300, ch)
        for i, ch in enumerate("0123456789/")
        if ch != " "
    ])

    return stage