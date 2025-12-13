from interpret_langauge.game_class import (
    GameStage,
    GameManager,
    AttackObject,
    PlatformObject,
)


def stage():
    stage = GameStage()

    # ================================================================
    # Game Manager Configuration
    # ================================================================
    stage.game_manager = GameManager(
        stage=1,
        wait_time=1,
        gravity_direction=3,
        display_pos_x1=136,
        display_pos_y1=256,
        display_pos_x2=508,
        display_pos_y2=384,
    )

    # ================================================================
    # Geometry / Timing Constants
    # ================================================================
    BAR_WIDTH = 12
    BAR_HEIGHT = 32
    ATTACK_SPEED = 12

    INITIAL_DELAY = 3
    NORMAL_DELAY = 0.3
    FINAL_DELAY = 2

    LEFT_X = stage.game_manager.display_pos_x1 - BAR_WIDTH
    TOP_Y = stage.game_manager.display_pos_y1
    BOTTOM_Y = stage.game_manager.display_pos_y2

    LOWER_Y = BOTTOM_Y - BAR_HEIGHT

    # ================================================================
    # Helper Functions
    # ================================================================
    def delay_block(seconds):
        return AttackObject(
            type=0,
            colider_type=0,
            movement_direction=2,
            speed=0,
            pos_x=0,
            pos_y=0,
            w=0,
            h=0,
            wait_time=seconds,
            destroy_time=0,
            destroy_trigger=2,
        )

    def left_lower_bar(wait, destroy):
        return AttackObject(
            type=0,
            colider_type=0,
            movement_direction=2,
            speed=ATTACK_SPEED,
            pos_x=LEFT_X,
            pos_y=LOWER_Y,
            w=BAR_WIDTH,
            h=BAR_HEIGHT,
            wait_time=wait,
            destroy_time=destroy,
            destroy_trigger=2,
        )

    # ================================================================
    # Initial Delay
    # ================================================================
    stage.attack_objects.append(delay_block(INITIAL_DELAY))

    # ================================================================
    # Phase 1: Repeating Lower Bars
    # ================================================================
    for _ in range(12):
        stage.attack_objects.append(
            left_lower_bar(NORMAL_DELAY, destroy=20)
        )

    # ================================================================
    # Phase 2: Break + Extension
    # ================================================================
    for _ in range(3):
        stage.attack_objects.append(left_lower_bar(0, destroy=20))
        stage.attack_objects.append(
            AttackObject(
                type=0,
                colider_type=0,
                movement_direction=2,
                speed=ATTACK_SPEED+3,
                pos_x=LEFT_X,
                pos_y=TOP_Y,
                w=BAR_WIDTH,
                h=44,
                wait_time=NORMAL_DELAY,
                destroy_time=20,
                destroy_trigger=2,
            )
        )

    # ================================================================
    # Phase 3: Resume Pressure
    # ================================================================
    for _ in range(8):
        stage.attack_objects.append(
            left_lower_bar(NORMAL_DELAY, destroy=20)
        )

    # ================================================================
    # Final Delay
    # ================================================================
    stage.attack_objects.append(delay_block(FINAL_DELAY))

    # ================================================================
    # Platforms
    # ================================================================
    stage.platform_objects.append(
        PlatformObject(
            movement_direction=2,
            speed=6,
            pos_x=137 - 62,
            pos_y=328,
            w=62,
            h=8,
            wait_time=2.5,
            destroy_time=20,
            destroy_trigger=2,
        )
    )

    for _ in range(5):
        stage.platform_objects.append(
            PlatformObject(
                movement_direction=2,
                speed=9,
                pos_x=137 - 62,
                pos_y=328,
                w=62,
                h=8,
                wait_time=1.5,
                destroy_time=20,
                destroy_trigger=2,
            )
        )

    return stage
