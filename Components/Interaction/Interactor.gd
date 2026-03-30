# Interactor.gd
# Simple raycast-based interaction detector
# Attach as child of Camera3D or WeaponManager, points in forward direction
# owner_entity handles the actual interaction logic through signals

class_name Interactor
extends RayCast3D

# Interaction signals - parent listens to these
signal interactable_detected(interactable: Interactable)
signal interactable_lost()
signal interaction_available(interactable: Interactable)

@export_category("Owner Entity")
@export var owner_entity: Node ## Who is doing the interaction? Player or Enemy? or whom?

# Configuration
@export_category("Interaction Settings")
@export var interaction_input: String = "interact"  # Input action name
@export var interaction_range: float = 3.0
@export var interaction_layer: int = 1  # Physics layer for interaction detection
@export var continuous_detection: bool = true  # Always detect or only on input

# State
var current_interactable: Interactable = null

func _ready() -> void:
	# Configure raycast
	target_position = Vector3(0, 0, -interaction_range)
	collision_mask = interaction_layer
	enabled = true
	
	# Add to interactors group for easy identification
	add_to_group("interactors")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed(interaction_input):
		request_interaction()

func _process(_delta: float) -> void:
	if continuous_detection:
		_detect_interactable()

# Main detection logic
func _detect_interactable() -> void:
	var found_interactable: Interactable = null
	
	# Check raycast collision
	if is_colliding():
		var collider = get_collider()
		if collider and collider.is_in_group("interactables"):
			found_interactable = collider as Interactable
			
			# Verify it can be interacted with
			if found_interactable and not found_interactable.can_interact(owner_entity):
				found_interactable = null
	
	# Update current interactable
	_update_current_interactable(found_interactable)

# Update the current interactable reference
func _update_current_interactable(new_interactable: Interactable) -> void:
	if current_interactable == new_interactable:
		return
	
	# Lost previous interactable
	if current_interactable:
		interactable_lost.emit()
	
	# Found new interactable
	current_interactable = new_interactable
	if current_interactable:
		interactable_detected.emit(current_interactable)
		interaction_available.emit(current_interactable)


# Parent calls this when they want to interact
func request_interaction() -> bool:
	if current_interactable and current_interactable.can_interact(owner_entity):
		var success = current_interactable.start_interaction(owner_entity)
		if success:
			# Interactable will be gone
			current_interactable = null
			interactable_lost.emit()
		return success
	return false

# Force detection (called by parent when needed)
func force_detect() -> void:
	_detect_interactable()

# Get current interactable info for UI
func get_current_interaction_info() -> Dictionary:
	if current_interactable:
		return current_interactable.get_interaction_info()
	return {}

# Check if we currently have an interactable
func has_interactable() -> bool:
	return current_interactable != null

# Get the current interactable (for parent to use)
func get_current_interactable() -> Interactable:
	return current_interactable

# Set interaction range and update raycast
func set_interaction_range(new_range: float) -> void:
	interaction_range = new_range
	target_position = Vector3(0, 0, -interaction_range)
