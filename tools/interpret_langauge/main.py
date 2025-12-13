from game_class import EntireGame, GameStage, GameManager, AttackObject, PlatformObject

game = EntireGame()


stage0 = GameStage()

stage0.game_manager = GameManager(
    stage=0,
    attack_amount=1,
    platform_amount=25,
    wait_time=5,
    gravity_direction=0,
    display_pos_x1=245,
    display_pos_y1=229,
    display_pos_x2=403,
    display_pos_y2=386
)

normal_speed = 12
initial_w = 12
initial_h_d = 72
initial_h_u = 46

attack_pairs = [
    (
        AttackObject(
            type=0, colider_type=0, movement_direction=0,
            speed=normal_speed,
            pos_x=stage0.game_manager.display_pos_x1,
            pos_y=stage0.game_manager.display_pos_y2 - initial_h_d - i * 8,
            w=initial_w,
            h=initial_h_d - i * 8,
            wait_time=0,
            destroy_time=20,
            destroy_trigger=2
        ),
        AttackObject(
            type=0, colider_type=0, movement_direction=0,
            speed=normal_speed,
            pos_x=stage0.game_manager.display_pos_x1,
            pos_y=stage0.game_manager.display_pos_y1,
            w=initial_w,
            h=initial_h_u + i * 8,
            wait_time=0,
            destroy_time=20,
            destroy_trigger=2
        )
    )
    for i in range(10)
]

# Add attack object
stage0.attack_objects.extend([
    # This is the inner object/item in the flat list:
    obj 
    
    # Outer Loop: Creates the 10 tuples (one for each iteration 'i')
    for i in range(10) 
    
    # Inner Loop: Iterates over the items (obj) inside the tuple/list created by 'i'
    for obj in (
        # The tuple you want to create in each iteration:
        AttackObject(
            type=0, colider_type=0, movement_direction=0,
            speed=normal_speed, pos_x=stage0.game_manager.display_pos_x1, 
            pos_y=stage0.game_manager.display_pos_y2 - initial_h_d - i*8,
            w=initial_w, h=initial_h_d - i*8, wait_time=0, destroy_time=20,
            destroy_trigger=2
        ), # <--- Comma separates the two items in the tuple

        AttackObject(
            type=0, colider_type=0, movement_direction=0,
            speed=normal_speed, pos_x=stage0.game_manager.display_pos_x1, 
            pos_y=stage0.game_manager.display_pos_y1,
            w=initial_w, h=initial_h_u + i*8, wait_time=0, destroy_time=20,
            destroy_trigger=2
        ) 
    )
])

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
