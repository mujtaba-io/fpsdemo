# Interactable.gd
# Simple interaction service provider for parent objects
# Attach this to objects that can be interacted with
# Parent handles the actual interaction logic via virtual functions

class_name Interactable
extends Area3D

# Interaction signals - parent and interactor listen to these
signal interaction_started(interactor: Node)
signal interaction_completed(interactor: Node)
signal interaction_cancelled(interactor: Node)
signal interaction_progress_updated(progress: float)

# Interaction types
enum InteractionType {
	MANUAL,    # Requires button press
	AUTOMATIC  # Triggers when entering area
}

enum InteractionDuration {
	INSTANT,   # Happens immediately
	TIMED      # Takes time to complete
}

# Configuration - typically set by parent or in inspector
@export_category("Interaction Settings")
@export var interaction_type: InteractionType = InteractionType.MANUAL
@export var interaction_duration: InteractionDuration = InteractionDuration.INSTANT
@export var interaction_time: float = 1.0  # Time needed for timed interactions
@export var interaction_prompt: String = "Interact"  # Text to display to player
@export var can_interrupt: bool = true  # Can interaction be cancelled mid-way
@export var auto_disable_after_use: bool = false  # Disable after one use
@export var interaction_range: float = 2.0  # Max distance for interaction

# State
var is_interacting: bool = false
var current_interactor: Node = null
var interaction_progress: float = 0.0
var is_enabled: bool = true

# Internal timer for timed interactions
var interaction_timer: Timer

func _ready() -> void:
	# Add to interactables group
	add_to_group("interactables")
	
	# Create timer for timed interactions
	interaction_timer = Timer.new()
	interaction_timer.wait_time = 0.1  # Update every 0.1 seconds
	interaction_timer.timeout.connect(_update_interaction_progress)
	add_child(interaction_timer)
	
	# Call parent setup
	if get_parent().has_method("setup_interaction"):
		get_parent().setup_interaction()

# Check if interaction is possible
func can_interact(interactor: Node) -> bool:
	if not is_enabled or is_interacting:
		return false
	
	# Check distance if interactor has global_position
	if interactor.has_method("get_global_position"):
		var distance = global_position.distance_to(interactor.global_position)
		if distance > interaction_range:
			return false
	
	# Ask parent if interaction is allowed
	if get_parent().has_method("can_interact_with"):
		return get_parent().can_interact_with(interactor)
	
	return true

# Start interaction
func start_interaction(interactor: Node) -> bool:
	if not can_interact(interactor):
		return false
	
	is_interacting = true
	current_interactor = interactor
	interaction_progress = 0.0
	
	interaction_started.emit(interactor)
	
	print("Interaction started")
	
	match interaction_duration:
		InteractionDuration.INSTANT:
			_complete_interaction()
		InteractionDuration.TIMED:
			interaction_timer.start()
	
	return true

# Update progress for timed interactions
func _update_interaction_progress() -> void:
	if not is_interacting or interaction_duration != InteractionDuration.TIMED:
		return
	
	interaction_progress += interaction_timer.wait_time / interaction_time
	interaction_progress_updated.emit(interaction_progress)
	
	if interaction_progress >= 1.0:
		_complete_interaction()

# Complete interaction
func _complete_interaction() -> void:
	if not is_interacting:
		return
	
	interaction_timer.stop()
	interaction_progress = 1.0
	
	# Ask parent to handle the interaction
	if get_parent().has_method("on_interaction_completed"):
		get_parent().on_interaction_completed(current_interactor)
	
	interaction_completed.emit(current_interactor)
	
	# Reset state
	is_interacting = false
	current_interactor = null
	interaction_progress = 0.0
	
	# Auto-disable if configured
	if auto_disable_after_use:
		is_enabled = false

# Cancel interaction
func cancel_interaction() -> void:
	if not is_interacting or not can_interrupt:
		return
	
	interaction_timer.stop()
	
	# Ask parent to handle cancellation
	if get_parent().has_method("on_interaction_cancelled"):
		get_parent().on_interaction_cancelled(current_interactor)
	
	interaction_cancelled.emit(current_interactor)
	
	# Reset state
	is_interacting = false
	current_interactor = null
	interaction_progress = 0.0

# Get interaction info for UI
func get_interaction_info() -> Dictionary:
	return {
		"prompt": interaction_prompt,
		"type": interaction_type,
		"duration": interaction_duration,
		"time": interaction_time,
		"progress": interaction_progress,
		"is_interacting": is_interacting,
		"can_interact": can_interact(current_interactor) if current_interactor else false
	}

# Enable/disable the interactable
func set_enabled(enabled: bool) -> void:
	is_enabled = enabled
	if not enabled and is_interacting:
		cancel_interaction()
