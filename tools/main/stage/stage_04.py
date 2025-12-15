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
    GAP = 150
    ATTACK_X = 235-GAP-ATTACK_SIZE+85
    ATTACK_Y = 480 - 145 - 70
    PLATFORM_X = 235+GAP+85
    PLATFORM_Y = 480 - 145 - 70

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
            wait_time=0.2,
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
            wait_time=0.2,
            destroy_time=0,
            destroy_trigger=2,
        )
    )

    # ------------------------------------------------------------------
    # Helper: Create Left / Right Wall Pair with Vertical Gap
    # ------------------------------------------------------------------
    def generate_attack():
        stage.attack_objects.extend([
                 AttackObject(
                    type=0,
                    colider_type=0,
                    movement_direction=i,
                    speed=3,
                    pos_x=ATTACK_X,
                    pos_y=ATTACK_Y,
                    w=ATTACK_SIZE,
                    h=ATTACK_SIZE,
                    wait_time=1,
                    destroy_time=4,
                    destroy_trigger=2,
                ) for i in range(8)
            
        ])

    def generate_platform():
        stage.platform_objects.extend([
                 PlatformObject(
                    movement_direction=i,
                    speed=3,
                    pos_x=PLATFORM_X,
                    pos_y=PLATFORM_Y,
                    w=ATTACK_SIZE,
                    h=ATTACK_SIZE,
                    wait_time=1,
                    destroy_time=4,
                    destroy_trigger=2,
                ) for i in range(8)
            
        ])

    # ------------------------------------------------------------------
    # Repeating Symmetric Wall Pattern
    # ------------------------------------------------------------------
    for i in range(2):
        generate_attack()
        generate_platform()

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
            wait_time=13.6,
            destroy_time=0,
            destroy_trigger=2,
        )
    )

    

    return stage
