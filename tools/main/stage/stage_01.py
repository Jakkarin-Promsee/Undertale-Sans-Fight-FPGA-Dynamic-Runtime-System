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
        wait_time=3,
        gravity_direction=3,
        display_pos_x1=136,
        display_pos_y1=256,
        display_pos_x2=508,
        display_pos_y2=386,
    )

    # ------------------------------------------------------------------
    # Common Parameters
    # ------------------------------------------------------------------
    ATTACK_SPEED = 12
    BAR_WIDTH = 12
    GAP_SIZE = 20

    SMALL_BAR_HEIGHT = 20
    MEDIUM_BAR_HEIGHT = 40
    LARGE_BAR_HEIGHT = 60

    LEFT_EDGE_X = stage.game_manager.display_pos_x1 - BAR_WIDTH
    RIGHT_EDGE_X = stage.game_manager.display_pos_x2

    TOP_EDGE_Y = stage.game_manager.display_pos_y1
    BOTTOM_EDGE_Y = stage.game_manager.display_pos_y2

    SCREEN_HEIGHT = BOTTOM_EDGE_Y - TOP_EDGE_Y

    LEFT_DELAY = 0
    RIGHT_DELAY = 1.5

    REPEAT_COUNT = 8

    # ------------------------------------------------------------------
    # Initial Delay (3 seconds)
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
            wait_time=3,
            destroy_time=0,
            destroy_trigger=2,
        )
    )

    # ------------------------------------------------------------------
    # Helper: Create Left / Right Wall Pair with Vertical Gap
    # ------------------------------------------------------------------
    def add_wall_pair(bar_height, right_delay):
        lower_y = BOTTOM_EDGE_Y - bar_height
        upper_h = SCREEN_HEIGHT - bar_height - GAP_SIZE

        stage.attack_objects.extend([
            # Left - Lower
            AttackObject(
                type=0,
                colider_type=0,
                movement_direction=2,
                speed=ATTACK_SPEED,
                pos_x=LEFT_EDGE_X,
                pos_y=lower_y,
                w=BAR_WIDTH,
                h=bar_height,
                wait_time=LEFT_DELAY,
                destroy_time=20,
                destroy_trigger=2,
            ),
            # Left - Upper
            AttackObject(
                type=0,
                colider_type=0,
                movement_direction=2,
                speed=ATTACK_SPEED,
                pos_x=LEFT_EDGE_X,
                pos_y=TOP_EDGE_Y,
                w=BAR_WIDTH,
                h=upper_h,
                wait_time=LEFT_DELAY,
                destroy_time=20,
                destroy_trigger=2,
            ),
            # Right - Lower
            AttackObject(
                type=0,
                colider_type=0,
                movement_direction=6,
                speed=ATTACK_SPEED,
                pos_x=RIGHT_EDGE_X,
                pos_y=lower_y,
                w=BAR_WIDTH,
                h=bar_height,
                wait_time=LEFT_DELAY,
                destroy_time=20,
                destroy_trigger=2,
            ),
            # Right - Upper (delayed)
            AttackObject(
                type=0,
                colider_type=0,
                movement_direction=6,
                speed=ATTACK_SPEED,
                pos_x=RIGHT_EDGE_X,
                pos_y=TOP_EDGE_Y,
                w=BAR_WIDTH,
                h=upper_h,
                wait_time=right_delay,
                destroy_time=20,
                destroy_trigger=2,
            ),
        ])

    # ------------------------------------------------------------------
    # Repeating Symmetric Wall Pattern
    # ------------------------------------------------------------------
    for _ in range(REPEAT_COUNT):
        add_wall_pair(
            bar_height=SMALL_BAR_HEIGHT,
            right_delay=RIGHT_DELAY,
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
            wait_time=2,
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
