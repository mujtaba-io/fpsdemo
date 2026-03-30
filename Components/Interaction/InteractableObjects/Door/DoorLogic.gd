# DoorLogic.gd
# Simple door that uses child Interactable for opening service
# Example of parent-child interaction system usage

class_name DoorLogic
extends StaticBody3D

# Door configuration
@export var is_open: bool = false
@export var open_angle: float = 90.0  # Degrees to rotate when opening
@export var open_speed: float = 2.0   # Speed of opening animation
@export var auto_close_time: float = 0.0  # Auto-close after X seconds (0 = never)
@export var requires_key: bool = false
@export var required_key_name: String = ""

# Components - assign in inspector
@export var interactable: Interactable
@export var door_mesh: MeshInstance3D
@export var door_sound: AudioStreamPlayer3D

# Internal state
var is_animating: bool = false
var closed_rotation: Vector3
var open_rotation: Vector3
var auto_close_timer: Timer

func _ready() -> void:
	# Store original rotation
	closed_rotation = rotation_degrees
	open_rotation = closed_rotation + Vector3(0, open_angle, 0)
	
	# Ensure we have required components
	if not interactable:
		interactable = get_node("Interactable") as Interactable
	
	# Set up auto-close timer
	if auto_close_time > 0:
		auto_close_timer = Timer.new()
		auto_close_timer.wait_time = auto_close_time
		auto_close_timer.one_shot = true
		auto_close_timer.timeout.connect(_auto_close_door)
		add_child(auto_close_timer)

# Called by Interactable when it's setting up
func setup_interaction(interaction_node: Interactable) -> void:
	if is_open:
		interaction_node.interaction_prompt = "Close Door"
	else:
		interaction_node.interaction_prompt = "Open Door"
	
	interaction_node.interaction_type = Interactable.InteractionType.MANUAL
	interaction_node.interaction_duration = Interactable.InteractionDuration.INSTANT

# Called by Interactable to check if interaction is allowed
func can_interact_with(interactor: Node) -> bool:
	# Don't allow interaction while animating
	if is_animating:
		return false
	
	# Check if key is required
	if requires_key and not is_open:
		if interactor.has_method("has_key"):
			return interactor.has_key(required_key_name)
		else:
			return false
	
	return true

# Called by Interactable when interaction completes
func on_interaction_completed(interactor: Node) -> void:
	if is_animating:
		return
	
	# Toggle door state
	if is_open:
		close_door()
	else:
		open_door()
	
	print("Door %s by %s" % ["closed" if is_open else "opened", interactor.name])

# Open the door
func open_door() -> void:
	if is_open or is_animating:
		return
	
	is_animating = true
	is_open = true
	
	# Update interaction prompt
	if interactable:
		interactable.interaction_prompt = "Close Door"
	
	# Animate rotation
	var tween = create_tween()
	tween.tween_property(self, "rotation_degrees", open_rotation, 1.0 / open_speed)
	tween.tween_callback(_on_door_animation_finished)
	
	# Play sound
	if door_sound:
		door_sound.play()
	
	# Start auto-close timer
	if auto_close_timer:
		auto_close_timer.start()

# Close the door
func close_door() -> void:
	if not is_open or is_animating:
		return
	
	is_animating = true
	is_open = false
	
	# Stop auto-close timer
	if auto_close_timer:
		auto_close_timer.stop()
	
	# Update interaction prompt
	if interactable:
		interactable.interaction_prompt = "Open Door"
	
	# Animate rotation
	var tween = create_tween()
	tween.tween_property(self, "rotation_degrees", closed_rotation, 1.0 / open_speed)
	tween.tween_callback(_on_door_animation_finished)
	
	# Play sound
	if door_sound:
		door_sound.play()

# Called when door animation finishes
func _on_door_animation_finished() -> void:
	is_animating = false

# Auto-close the door
func _auto_close_door() -> void:
	if is_open and not is_animating:
		close_door()

# Called when interaction is cancelled (not needed for doors)
func on_interaction_cancelled(_interactor: Node) -> void:
	pass
