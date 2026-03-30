# WeaponPickup.gd
# Simple world representation of a weapon that can be picked up
# Just holds WeaponData and provides interaction

class_name WeaponPickup
extends RigidBody3D

# The weapon data this pickup represents
@export var weapon_data: WeaponData

# Child components - assign in inspector or will be auto-created
@export var interactable: Interactable

func _ready() -> void:
	# Ensure we have an interactable component
	if not interactable:
		push_error("Interactable not assigned to World WeaponEquipped.")
	
	# Setup interaction if we have weapon data
	setup_interaction_prompt.call_deferred()


func setup_interaction_prompt():
	if interactable and weapon_data:
		interactable.interaction_prompt = "Pick up " + weapon_data.weapon_name


# Called by Interactable to check if interaction is allowed
func can_interact_with(interactor: Node) -> bool:
	# Only allow pickup if we have weapon data
	if not weapon_data:
		return false
	
	# Check if interactor has a weapon manager (can receive weapons)
	var weapon_manager = interactor.weapons_manager as WeaponManager
	return weapon_manager != null

# Called by Interactable when interaction completes
func on_interaction_completed(interactor: Node) -> void:
	var weapon_manager = interactor.weapons_manager as WeaponManager
	
	if weapon_manager:
		# Attempt pickup - pass the weapon data directly
		if weapon_manager.pickup_weapon(weapon_data):
			# Pickup successful - remove from world
			queue_free()
		else:
			# Pickup failed (maybe already have weapon or full ammo)
			print("Cannot pick up ", weapon_data.weapon_name)
	else:
		print("No weapon manager found on interactor")


# Set weapon data (called when instantiated from weapon throwing)
func set_weapon_data(data: WeaponData) -> void:
	weapon_data = data

# Called when interaction is cancelled
func on_interaction_cancelled(_interactor: Node) -> void:
	# Nothing needed for cancellation
	pass
