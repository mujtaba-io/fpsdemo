# Health.gd
# A reusable health component for both players and enemies
class_name Health
extends Node

signal health_changed(current_health: int, max_health: int)
signal died()

@export var initial_max_health: int = 100
@export var is_player: bool = false # Players have different death behavior

var current_health: int
var max_health: int

func _ready():
	max_health = initial_max_health
	current_health = max_health

func take_damage(damage_amount: int) -> void:
	# Only reduce current health, keep max health constant
	current_health = max(0, current_health - damage_amount)
	
	health_changed.emit(current_health, max_health)
	
	print("%s took %d damage! Health: %d/%d" % [get_parent().name, damage_amount, current_health, max_health])
	
	if current_health <= 0:
		died.emit()

func get_health_percentage() -> float:
	if max_health <= 0:
		return 0.0
	return float(current_health) / float(max_health)

func is_alive() -> bool:
	return current_health > 0

func heal(amount: int) -> void:
	# Healing only restores current health, not max health
	current_health = min(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)
