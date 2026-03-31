# ObjectivesSystem/KillObjective.gd
class_name KillObjective
extends BaseObjective

@export var target_enemy: NodePath
@export var required_kills: int = 1

var enemy_node: Node
var kills: int = 0
var health_component: Health

func initialize(manager: ObjectiveManager) -> void:
	print("KillObjective: Setting up kill tracking...")
	print("Target kills required: ", required_kills)
	
	if not target_enemy.is_empty():
		enemy_node = manager.get_node(target_enemy)
		
		if enemy_node:
			print("Found target enemy: ", enemy_node.name)
			# Try to find Health component component
			health_component = enemy_node.health_component
			
			if health_component:
				if not health_component.died.is_connected(_on_enemy_died):
					health_component.died.connect(_on_enemy_died)
					print("Connected to enemy's health system")
					print("Objective: Eliminate the target enemy")
			else:
				print("Enemy node doesn't have a Health component!")
				push_error("KillObjective: Enemy node doesn't have a Health component!")
		else:
			print("Could not find enemy node at path: ", target_enemy)
			push_error("KillObjective: Could not find enemy node at path: ", target_enemy)
	else:
		print("No target enemy assigned!")
		push_error("KillObjective: No target enemy assigned!")

func cleanup() -> void:
	if health_component and health_component.died.is_connected(_on_enemy_died):
		health_component.died.disconnect(_on_enemy_died)

func _on_enemy_died() -> void:
	kills += 1
	print("Enemy eliminated! Kills: ", kills, "/", required_kills)
	
	if show_progress:
		update_progress(float(kills) / float(required_kills))
	
	if kills >= required_kills:
		print("All required enemies eliminated!")
		complete()
	else:
		var remaining = required_kills - kills
		print("Enemies remaining: ", remaining)
