# Alarm.gd
# An interactable alarm that can be toggled on/off
# Extends Interactable to use the interaction system

class_name Alarm
extends Node3D

# Alarm state
var is_alarm_active: bool = false

# Reference to the interactable component
@export var interactable: Interactable

func _ready() -> void:
	# Connect to interaction signals
	interactable.interaction_completed.connect(_on_interaction_completed)

# Called by interactable when interaction is completed
func _on_interaction_completed(_interactor: Node) -> void:
	toggle_alarm()

# Toggle the alarm state
func toggle_alarm() -> void:
	is_alarm_active = not is_alarm_active
	
	if is_alarm_active:
		activate_alarm()
	else:
		deactivate_alarm()

# Activate the alarm
func activate_alarm() -> void:
	print("ALARM: Alarm activated!")
	# Update interaction prompt
	interactable.interaction_prompt = "Turn Off Alarm"
	
	# Here you would add visual/audio effects:
	# - Start flashing lights
	# - Play alarm sound
	# - Change material colors
	# etc.

# Deactivate the alarm
func deactivate_alarm() -> void:
	print("ALARM: Alarm deactivated.")
	# Update interaction prompt
	interactable.interaction_prompt = "Turn On Alarm"
	
	# Here you would stop visual/audio effects:
	# - Stop flashing lights
	# - Stop alarm sound
	# - Reset material colors
	# etc.

# Public function to check alarm state
func is_active() -> bool:
	return is_alarm_active

# Public function to set alarm state without interaction
func set_alarm_state(active: bool) -> void:
	if is_alarm_active != active:
		toggle_alarm()

# Enable/disable the alarm interaction
func set_interactable_enabled(enabled: bool) -> void:
	if interactable:
		interactable.set_enabled(enabled)

# Get the current interaction prompt for UI
func get_interaction_prompt() -> String:
	if interactable:
		return interactable.interaction_prompt
	return "Toggle Alarm"
