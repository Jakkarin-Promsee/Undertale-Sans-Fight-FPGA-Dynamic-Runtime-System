import sys, os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..')))
from interpret_langauge.game_class import GameUIStage, GameUI, CharacterObject

from main.stage_ui import center_data

def stage():
    stage = GameUIStage()

    stage.game_ui = GameUI(
        show_healt_text=1,
        reset_character=1,
        transparent_out_screen_display=1,
        healt_current=0,
        healt_max=0,
        healt_bar_pos_x=0,
        healt_bar_pos_y=0,
        healt_bar_w=0,
        healt_bar_h=0,
        healt_bar_sensitivity=0.04,
        wait_time=2
    )

    return stage