# ObjectivesSystem/MultiKillObjective.gd
class_name MultiKillObjective
extends BaseObjective

@export var enemy_group: String = "enemies"
@export var required_kills: int = 5

var kills: int = 0

var objective_manager: ObjectiveManager

func initialize(manager: ObjectiveManager) -> void:
	print("MultiKillObjective: Setting up multi-enemy kill tracking...")
	print("Target group: '", enemy_group, "' | Required kills: ", required_kills)
	
	objective_manager = manager
	# Connect to all enemies in the group
	var enemies = objective_manager.get_tree().get_nodes_in_group(enemy_group)
	print("Found ", enemies.size(), " enemies in group '", enemy_group, "'")
	
	var connected_count = 0
	for enemy in enemies:
		var health_component = enemy.health_component
		if health_component and not health_component.died.is_connected(_on_enemy_died):
			health_component.died.connect(_on_enemy_died)
			connected_count += 1
	
	print("Connected to ", connected_count, " enemy health systems")
	print("Objective: Eliminate ", required_kills, " enemies from group '", enemy_group, "'")
	
	# Also connect to any new enemies that might be added later
	if not objective_manager.get_tree().node_added.is_connected(_on_node_added):
		objective_manager.get_tree().node_added.connect(_on_node_added)

func cleanup() -> void:
	# Disconnect from all enemies
	var enemies = objective_manager.get_tree().get_nodes_in_group(enemy_group)
	for enemy in enemies:
		var health_component = enemy.health_component
		if health_component and health_component.died.is_connected(_on_enemy_died):
			health_component.died.disconnect(_on_enemy_died)
	
	# Disconnect from node_added signal
	if objective_manager.get_tree().node_added.is_connected(_on_node_added):
		objective_manager.get_tree().node_added.disconnect(_on_node_added)

func _on_node_added(node: Node) -> void:
	# Check if new node is an enemy and connect to its Health component
	if node.is_in_group(enemy_group):
		print("New enemy added to group '", enemy_group, "': ", node.name)
		var health_component = node.health_component
		if health_component and not health_component.died.is_connected(_on_enemy_died):
			health_component.died.connect(_on_enemy_died)
			   print("Connected to new enemy's health system")

func _on_enemy_died() -> void:
	kills += 1
	print("Enemy from group '", enemy_group, "' eliminated! Kills: ", kills, "/", required_kills)
	
	if show_progress:
		update_progress(float(kills) / float(required_kills))
	
	if kills >= required_kills:
		print("All required enemies from group '", enemy_group, "' eliminated!")
		complete()
	else:
		var remaining = required_kills - kills
		print("Enemies remaining: ", remaining)
