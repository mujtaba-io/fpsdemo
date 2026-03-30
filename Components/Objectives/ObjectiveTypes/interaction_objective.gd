# ObjectivesSystem/InteractionObjective.gd
class_name InteractionObjective
extends BaseObjective

@export var target_interactable_nodepath: NodePath
var target_interactable: Interactable

var objective_manager: ObjectiveManager

func initialize(manager: ObjectiveManager) -> void:
	print("InteractionObjective: Setting up interaction detection...")
	objective_manager = manager
	
	target_interactable = manager.get_node(target_interactable_nodepath).interactable # Hacky?
	
	if target_interactable:
		print("Found target interactable: ", target_interactable.name if target_interactable.has_method("get_name") else "Unknown")
		# Connect to the interactable's completion signal
		if not target_interactable.interaction_completed.is_connected(_on_interaction_completed):
			target_interactable.interaction_completed.connect(_on_interaction_completed)
		print("Objective: Interact with the target object")
	else:
		print("No target interactable assigned!")
		push_error("InteractionObjective: No target interactable assigned!")

func cleanup() -> void:
	if target_interactable and target_interactable.interaction_completed.is_connected(_on_interaction_completed):
		target_interactable.interaction_completed.disconnect(_on_interaction_completed)

func _on_interaction_completed(interactor: Node) -> void:
	print("Interaction detected with: ", interactor.name)
	# Only complete if the player interacted
	if interactor.is_in_group("players"):
		print("Player successfully completed the interaction!")
		complete()
	else:
		print("Non-player interaction - waiting for player...")
