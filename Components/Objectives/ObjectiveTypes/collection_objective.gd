# ObjectivesSystem/CollectionObjective.gd
class_name CollectionObjective
extends BaseObjective

@export var item_name: String = "Key"
@export var required_count: int = 1

var collected: int = 0

var player: Node

func initialize(manager: ObjectiveManager) -> void:
	print("CollectionObjective: Setting up item collection tracking...")
	print("Target item: '", item_name, "' | Required count: ", required_count)
	
	# Connect to player's inventory signals if available
	player = manager.get_tree().get_first_node_in_group("players")
	if player:
		print("Found player: ", player.name)
		if player.has_method("item_collected"):
			if not player.item_collected.is_connected(_on_item_collected):
				player.item_collected.connect(_on_item_collected)
			   print("Connected to player's item collection signal")
			   print("Objective: Collect ", required_count, " '", item_name, "' items")
		else:
			   print("Player doesn't have item_collected signal - collection tracking may not work")
	else:
		print("No player found in 'players' group!")

func cleanup() -> void:
	if player and player.has_method("item_collected") and player.item_collected.is_connected(_on_item_collected):
		player.item_collected.disconnect(_on_item_collected)

func _on_item_collected(item_id: String, count: int) -> void:
	print("Item collected: ", item_id, " (count: ", count, ")")
	
	if item_id == item_name:
		collected += count
		print("Target item collected! Total: ", collected, "/", required_count)
		
		if show_progress:
			update_progress(float(collected) / float(required_count))
		
		if collected >= required_count:
			   print("All required '", item_name, "' items collected!")
			complete()
		else:
			var remaining = required_count - collected
			   print("Items remaining: ", remaining)
	else:
		print("Not the target item (need '", item_name, "')")
