import json
import os


# ================================================================
# 1. Game Manager
# ================================================================
class GameManager:
    def __init__(self,
                 stage=0,
                 attack_amount=0,
                 platform_amount=0,
                 wait_time=0,
                 gravity_direction=0,
                 display_pos_x1=0,
                 display_pos_y1=0,
                 display_pos_x2=0,
                 display_pos_y2=0,
                 free_unused=0):

        self.stage = stage
        self.attack_amount = attack_amount
        self.platform_amount = platform_amount
        self.wait_time = wait_time
        self.gravity_direction = gravity_direction
        self.display_pos_x1 = display_pos_x1
        self.display_pos_y1 = display_pos_y1
        self.display_pos_x2 = display_pos_x2
        self.display_pos_y2 = display_pos_y2
        self.free_unused = free_unused

    def to_dict(self):
        return {
            "stage": self.stage,
            "attack_amount": self.attack_amount,
            "platform_amount": self.platform_amount,
            "wait_time": self.wait_time,
            "gravity_direction": self.gravity_direction,
            "display_pos_x1": self.display_pos_x1,
            "display_pos_y1": self.display_pos_y1,
            "display_pos_x2": self.display_pos_x2,
            "display_pos_y2": self.display_pos_y2,
            "free(unused)": self.free_unused
        }


# ================================================================
# 2. Attack Object
# ================================================================
class AttackObject:
    def __init__(self,
                 type=0,
                 colider_type=0,
                 movement_direction=0,
                 speed=0,
                 pos_x=0,
                 pos_y=0,
                 w=0,
                 h=0,
                 wait_time=0,
                 destroy_time=0,
                 destroy_trigger=0,
                 free_unused=0):

        self.type = type
        self.colider_type = colider_type
        self.movement_direction = movement_direction
        self.speed = speed
        self.pos_x = pos_x
        self.pos_y = pos_y
        self.w = w
        self.h = h
        self.wait_time = wait_time
        self.destroy_time = destroy_time
        self.destroy_trigger = destroy_trigger
        self.free_unused = free_unused

    def to_dict(self):
        return {
            "type": self.type,
            "colider_type": self.colider_type,
            "movement_direction": self.movement_direction,
            "speed": self.speed,
            "pos_x": self.pos_x,
            "pos_y": self.pos_y,
            "w": self.w,
            "h": self.h,
            "wait_time": self.wait_time,
            "destroy_time": self.destroy_time,
            "destroy_trigger": self.destroy_trigger,
            "free(unused)": self.free_unused
        }


# ================================================================
# 3. Platform Object
# ================================================================
class PlatformObject:
    def __init__(self,
                 movement_direction=0,
                 speed=0,
                 pos_x=0,
                 pos_y=0,
                 w=0,
                 h=0,
                 wait_time=0,
                 destroy_time=0,
                 destroy_trigger=0,
                 free_unused=0):

        self.movement_direction = movement_direction
        self.speed = speed
        self.pos_x = pos_x
        self.pos_y = pos_y
        self.w = w
        self.h = h
        self.wait_time = wait_time
        self.destroy_time = destroy_time
        self.destroy_trigger = destroy_trigger
        self.free_unused = free_unused

    def to_dict(self):
        return {
            "movement_direction": self.movement_direction,
            "speed": self.speed,
            "pos_x": self.pos_x,
            "pos_y": self.pos_y,
            "w": self.w,
            "h": self.h,
            "wait_time": self.wait_time,
            "destroy_time": self.destroy_time,
            "destroy_trigger": self.destroy_trigger,
            "free(unused)": self.free_unused
        }


# ================================================================
# 4. Game Stage (One stage = GM + objects)
# ================================================================
class GameStage:
    def __init__(self, game_manager=None):
        self.game_manager = game_manager or GameManager()
        self.attack_objects = []
        self.platform_objects = []

    def to_dict(self):
        return {
            "game_manger": self.game_manager.to_dict(),
            "attack_object": [obj.to_dict() for obj in self.attack_objects],
            "platform_object": [obj.to_dict() for obj in self.platform_objects]
        }


# ================================================================
# 5. Entire Game (multiple stages)
# ================================================================
class EntireGame:
    def __init__(self):
        self.stages = []

    def add_stage(self, stage: GameStage):
        self.stages.append(stage)

    # ---- EXPORT to many stageXX.json ----
    def export(self, directory="output"):
        # Base path for this file
        base_path = os.path.dirname(os.path.abspath(__file__))

        # Final output folder
        export_folder = os.path.join(base_path, directory)

        # Create directory if missing
        os.makedirs(export_folder, exist_ok=True)

        # Export each stage
        for i, stage in enumerate(self.stages):
            output_path = os.path.join(export_folder, f"stage{i:02}.json")
            with open(output_path, "w") as f:
                json.dump(stage.to_dict(), f, indent=4)

        print(f"Exported {len(self.stages)} stages → {export_folder}/")