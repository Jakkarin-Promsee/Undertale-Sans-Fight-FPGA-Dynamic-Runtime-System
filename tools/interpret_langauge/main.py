from game_class import EntireGame, GameStage, GameManager, AttackObject, PlatformObject

game = EntireGame()

# Create Stage 0
gm = GameManager(
    stage=0,
    attack_amount=1,
    platform_amount=1,
    wait_time=1,
    gravity_direction=3,
    display_pos_x1=130,
    display_pos_y1=251,
    display_pos_x2=506,
    display_pos_y2=391
)

stage0 = GameStage(game_manager=gm)

# Add attack object
stage0.attack_objects.append(
    AttackObject(
        type=0, colider_type=i, movement_direction=0,
        speed=0, pos_x=320, pos_y=240,
        w=20, h=20, wait_time=2, destroy_time=0,
        destroy_trigger=2
    ) 
)

# Add platform object
stage0.platform_objects.append(
    PlatformObject(
        movement_direction=2, speed=0,
        pos_x=340, pos_y=300,
        w=40, h=6, wait_time=2,
        destroy_time=5, destroy_trigger=2
    )
)

game.add_stage(stage0)

# Export
game.export("output")
