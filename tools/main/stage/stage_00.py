import sys, os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..')))
from interpret_langauge.game_class import GameStage, GameManager, AttackObject, PlatformObject


def stage():
    stage = GameStage()

    # ------------------------------------------------------------------
    # Game Manager Configuration
    # ------------------------------------------------------------------
    stage.game_manager = GameManager(
        stage=0,
        wait_time=3,
        gravity_direction=0,
        display_pos_x1=245,
        display_pos_y1=229,
        display_pos_x2=403,
        display_pos_y2=386,
    )

    # ------------------------------------------------------------------
    # Common Parameters
    # ------------------------------------------------------------------
    ATTACK_SPEED = 12
    BAR_WIDTH = 12

    LOWER_BAR_BASE_HEIGHT = 72
    UPPER_BAR_BASE_HEIGHT = 46

    STEP = 8

    LOWER_DELAY = 0
    UPPER_DELAY = 0.2

    LEFT_EDGE_X = stage.game_manager.display_pos_x1 - BAR_WIDTH
    TOP_EDGE_Y = stage.game_manager.display_pos_y1
    BOTTOM_EDGE_Y = stage.game_manager.display_pos_y2

    # ------------------------------------------------------------------
    # Initial Delay (5 seconds)
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
            wait_time=5,
            destroy_time=0,
            destroy_trigger=2,
        )
    )

    # ------------------------------------------------------------------
    # Helper: Create Paired Upper / Lower Bars
    # ------------------------------------------------------------------
    def add_bar_pair(index, lower_y, lower_h, upper_h):
        stage.attack_objects.extend([
            AttackObject(
                type=0,
                colider_type=0,
                movement_direction=2,
                speed=ATTACK_SPEED,
                pos_x=LEFT_EDGE_X,
                pos_y=lower_y,
                w=BAR_WIDTH,
                h=lower_h,
                wait_time=LOWER_DELAY,
                destroy_time=20,
                destroy_trigger=2,
            ),
            AttackObject(
                type=0,
                colider_type=0,
                movement_direction=2,
                speed=ATTACK_SPEED,
                pos_x=LEFT_EDGE_X,
                pos_y=TOP_EDGE_Y,
                w=BAR_WIDTH,
                h=upper_h,
                wait_time=UPPER_DELAY,
                destroy_time=20,
                destroy_trigger=2,
            ),
        ])

    # ------------------------------------------------------------------
    # Phase 1: Expanding Gap
    # ------------------------------------------------------------------
    PHASE1_STEPS = 4
    for i in range(PHASE1_STEPS + 1):
        add_bar_pair(
            i,
            lower_y=BOTTOM_EDGE_Y - LOWER_BAR_BASE_HEIGHT - i * STEP,
            lower_h=LOWER_BAR_BASE_HEIGHT + i * STEP,
            upper_h=UPPER_BAR_BASE_HEIGHT - i * STEP,
        )

    # ------------------------------------------------------------------
    # Phase 2: Contracting Gap
    # ------------------------------------------------------------------
    PHASE2_STEPS = 11
    for i in range(PHASE2_STEPS + 1):
        add_bar_pair(
            i,
            lower_y=(
                BOTTOM_EDGE_Y
                - LOWER_BAR_BASE_HEIGHT
                + i * STEP
                - PHASE1_STEPS * STEP
            ),
            lower_h=(
                LOWER_BAR_BASE_HEIGHT
                - i * STEP
                + PHASE1_STEPS * STEP
            ),
            upper_h=(
                UPPER_BAR_BASE_HEIGHT
                + i * STEP
                - PHASE1_STEPS * STEP
            ),
        )

    # ------------------------------------------------------------------
    # Phase 3: Re-expanding Gap
    # ------------------------------------------------------------------
    PHASE3_STEPS = 6
    for i in range(PHASE3_STEPS + 1):
        add_bar_pair(
            i,
            lower_y=(
                BOTTOM_EDGE_Y
                - LOWER_BAR_BASE_HEIGHT
                - i * STEP
                + PHASE2_STEPS * STEP
                - PHASE1_STEPS * STEP
            ),
            lower_h=(
                LOWER_BAR_BASE_HEIGHT
                + i * STEP
                - PHASE2_STEPS * STEP
                + PHASE1_STEPS * STEP
            ),
            upper_h=(
                UPPER_BAR_BASE_HEIGHT
                - i * STEP
                + PHASE2_STEPS * STEP
                - PHASE1_STEPS * STEP
            ),
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
