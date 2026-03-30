# revolver.gd
extends WeaponEquipped

var last_fire_time: float = 0.0

func attack() -> void:
	if not weapon_data:
		return
		
	# Check ammunition first
	if not can_fire():
		print("Revolver: Cannot fire - no ammo or reloading")
		return
	
	# Check if enough time has passed based on recovery delay
	var current_ticks = Time.get_ticks_msec() / 1000.0
	
	if current_ticks - last_fire_time < weapon_data.recovery_delay:
		return
	
	last_fire_time = current_ticks
	
	print("Revolver: PEW!")
	
	# Tell the base script to perform the hitscan logic.
	fire_hitscan(weapon_data.damage)
	
	# Check if we're still in recoil and apply impact multiplier
	var current_recoil = get_current_recoil_amount()
	var impact_multiplier = 1.0
	if current_recoil > 0.05:  # If there's significant recoil happening (lower threshold for revolver)
		impact_multiplier = weapon_data.recoil_impact_multiplier
		print("Revolver: Firing during recoil! Impact increased by ", impact_multiplier, "x")
	
	# Tell the base weapon script to apply our recoil values with potential impact multiplier
	apply_recoil(weapon_data.recoil_kickback * impact_multiplier, weapon_data.recoil_rotation_degrees * impact_multiplier)

func get_current_recoil_amount() -> float:
	if not weapon_model:
		return 0.0
	
	# Calculate how far the weapon is displaced from its original position
	var displacement = weapon_model.position.distance_to(_original_model_position)
	var rotation_diff = weapon_model.rotation.distance_to(_original_model_rotation)
	
	return displacement + rotation_diff
