# ObjectivesSystem/AreaObjective.gd
class_name AreaObjective
extends BaseObjective

@export var target_area_nodepath: NodePath ## Area3D

var target_area: Area3D

func initialize(manager: ObjectiveManager) -> void:
	print("AreaObjective: Setting up area detection...")
	target_area = manager.get_node(target_area_nodepath) as Area3D
	
	if target_area:
		if not target_area.body_entered.is_connected(_on_area_entered):
			target_area.body_entered.connect(_on_area_entered)
		print("AreaObjective: Connected to area '", target_area.name, "'")
		print("Objective: Reach the designated area")
	else:
		print("AreaObjective: No target area assigned!")
		push_error("AreaObjective: No target area assigned!")

func cleanup() -> void:
	if target_area and target_area.body_entered.is_connected(_on_area_entered):
		target_area.body_entered.disconnect(_on_area_entered)

func _on_area_entered(body: Node) -> void:
	print("Someone entered the area: ", body.name)
	# Only complete if the player entered the area
	if body.is_in_group("players"):
		print("Player reached the target area!")
		complete()
	else:
		print("Not the player - waiting for player to enter...")
