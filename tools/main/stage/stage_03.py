import sys, os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..')))
from interpret_langauge.game_class import GameStage, GameManager, AttackObject, PlatformObject


def stage():
    stage = GameStage()

    # ------------------------------------------------------------------
    # Game Manager Configuration
    # ------------------------------------------------------------------
    stage.game_manager = GameManager(
        stage=1,
        wait_time=1,
        gravity_direction=0,
        display_pos_x1=0,
        display_pos_y1=0,
        display_pos_x2=0,
        display_pos_y2=0,
    )

    # ------------------------------------------------------------------
    # Common Parameters
    # ------------------------------------------------------------------
    ATTACK_SIZE = 20
    ATTACK_GAP = 30
    ATTACK_X = 85
    ATTACK_Y = 140

    # ------------------------------------------------------------------
    # Initial Delay (2 seconds)
    # ------------------------------------------------------------------
    stage.attack_objects.append(
        AttackObject(
            type=0,
            colider_type=0,
            movement_direction=2,
            speed=0,
            pos_x=0,
            pos_y=0,
            w=0,
            h=0,
            wait_time=2,
            destroy_time=0,
            destroy_trigger=2,
        )
    )

    # ------------------------------------------------------------------
    # Helper: Create Left / Right Wall Pair with Vertical Gap
    # ------------------------------------------------------------------
    def generate_row(attack_y, i_speed):

        stage.attack_objects.extend([
            
                 AttackObject(
                    type=0,
                    colider_type=0,
                    movement_direction=4,
                    speed=i_speed+i,
                    pos_x=ATTACK_X + (ATTACK_SIZE+ATTACK_GAP)*i,
                    pos_y=attack_y,
                    w=ATTACK_SIZE,
                    h=ATTACK_SIZE,
                    wait_time=0,
                    destroy_time=4,
                    destroy_trigger=2,
                ) for i in range(10)
            
        ])

    # ------------------------------------------------------------------
    # Repeating Symmetric Wall Pattern
    # ------------------------------------------------------------------
    for i in range(3):
        generate_row(
            ATTACK_Y,
            i*10
        )

    # ------------------------------------------------------------------
    # Last Delay (5 seconds)
    # ------------------------------------------------------------------
    stage.attack_objects.append(
        AttackObject(
            type=0,
            colider_type=0,
            movement_direction=2,
            speed=0,
            pos_x=0,
            pos_y=0,
            w=0,
            h=0,
            wait_time=7,
            destroy_time=0,
            destroy_trigger=2,
        )
    )

    # ------------------------------------------------------------------
    # Platform Placeholder (No Movement)
    # ------------------------------------------------------------------
    stage.platform_objects.append(
        PlatformObject(
            movement_direction=2,
            speed=0,
            pos_x=0,
            pos_y=0,
            w=0,
            h=0,
            wait_time=0,
            destroy_time=0,
            destroy_trigger=2,
        )
    )

    return stage
