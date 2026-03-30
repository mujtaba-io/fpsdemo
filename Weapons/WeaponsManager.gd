# weapon_manager.gd
# This node manages which weapon is currently active.
# It handles spawning, despawning, and switching weapons via mouse wheel.
# It also forwards attack commands and damage signals from the active weapon to the player.
# Now includes Interactor child for weapon pickup detection.

class_name WeaponManager
extends Node3D

# Signals
# This signal is a "pass-through" from the weapon. The Player will connect to this.
signal weapon_dealt_damage(damage_amount: int, hit_point: Vector3, hit_normal: Vector3, collider: Object)
signal weapon_ammo_changed(current_magazine: int, total_ammo: int)
signal weapon_reload_started()
signal weapon_reload_finished()

# Exports
# Assign your weapon data resources (e.g., Shotgun.tres, Revolver.tres) to this array in the Inspector.
@export var weapon_data_array: Array[WeaponData]
@export var shooter_body: Node3D ## Owner/self who shoots, to prevent suicide

# Private Variables
var current_weapon_index: int = -1
var current_weapon_instance: WeaponEquipped # Using the WeaponEquipped class_name for type safety
var weapon_instances: Array[WeaponEquipped] = [] # Pool of weapon instances to preserve ammo states
var weapons_initialized: bool = false

func _ready() -> void:
	# Initialize all weapon instances first
	_initialize_all_weapons.call_deferred() ## Always call_deffered() it since WeaponSystem loads before Player
	
	# Equip the first weapon in the array by default when the game starts.
	if not weapon_data_array.is_empty():
		switch_weapon.call_deferred(0)
	else:
		print("WeaponManager: No weapon data assigned.")


# Public functions for PlayerController to call
func switch_to_next_weapon() -> void:
	if weapon_data_array.size() <= 1:
		return
	
	var new_index = current_weapon_index + 1
	if new_index >= weapon_data_array.size():
		new_index = 0
	
	switch_weapon(new_index)

func switch_to_previous_weapon() -> void:
	if weapon_data_array.size() <= 1:
		return
	
	var new_index = current_weapon_index - 1
	if new_index < 0:
		new_index = weapon_data_array.size() - 1
	
	switch_weapon(new_index)

func throw_weapon_with_force(throw_strength: float = 7.5) -> void:
	var throw_force = get_throw_direction(throw_strength)
	throw_current_weapon(throw_force)

# This is the public function your Player script will call.
func attack() -> void:
	if current_weapon_instance:
		current_weapon_instance.attack()

func reload_current_weapon() -> void:
	if current_weapon_instance and current_weapon_instance.has_method("manual_reload"):
		current_weapon_instance.manual_reload()

func get_current_weapon_ammo_info() -> Dictionary:
	if current_weapon_instance and current_weapon_instance.has_method("get_ammo_info"):
		return current_weapon_instance.get_ammo_info()
	return {}

func get_all_weapon_ammo_info() -> Array[Dictionary]:
	var all_ammo_info: Array[Dictionary] = []
	for i in range(weapon_instances.size()):
		var weapon = weapon_instances[i]
		if weapon and weapon.has_method("get_ammo_info"):
			var info = weapon.get_ammo_info()
			info["weapon_index"] = i
			info["weapon_name"] = weapon.name
			all_ammo_info.append(info)
		else:
			all_ammo_info.append({"weapon_index": i, "weapon_name": "null", "error": "No weapon instance"})
	return all_ammo_info

# Initialize all weapon instances once to preserve their states
func _initialize_all_weapons() -> void:
	if weapons_initialized:
		return
	
	weapon_instances.clear()
	
	for i in range(weapon_data_array.size()):
		var weapon_data = weapon_data_array[i]
		if weapon_data and weapon_data.weapon_equipped_scene:
			var weapon_instance = weapon_data.weapon_equipped_scene.instantiate()
			weapon_instance.shooter_body = shooter_body
			weapon_instance.custom_fire_origin = get_viewport().get_camera_3d() if shooter_body in get_tree().get_nodes_in_group("players") else null
			
			print("shooter body in players????", shooter_body in get_tree().get_nodes_in_group("players"))
	
			
			# Assign weapon data to the weapon instance
			if weapon_instance.has_method("set_weapon_data"):
				weapon_instance.set_weapon_data(weapon_data)
			
			# Ensure the instantiated scene is actually a WeaponEquipped.
			if not weapon_instance is WeaponEquipped:
				printerr("Scene at index %d is not a valid WeaponEquipped scene." % i)
				weapon_instance.queue_free()
				weapon_instances.append(null)
				continue
			
			# Add to scene tree but hide initially
			add_child(weapon_instance)
			weapon_instance.visible = false
			weapon_instance.set_process_mode(Node.PROCESS_MODE_DISABLED)
			
			# Connect signals
			weapon_instance.deal_damage.connect(_on_weapon_deal_damage)
			if weapon_instance.has_signal("ammo_changed"):
				weapon_instance.ammo_changed.connect(_on_weapon_ammo_changed)
			if weapon_instance.has_signal("reload_started"):
				weapon_instance.reload_started.connect(_on_weapon_reload_started)
			if weapon_instance.has_signal("reload_finished"):
				weapon_instance.reload_finished.connect(_on_weapon_reload_finished)
			
			weapon_instances.append(weapon_instance)
		else:
			weapon_instances.append(null)
	
	weapons_initialized = true
	print("WeaponManager: Initialized %d weapon instances" % weapon_instances.size())

# This function handles the logic of equipping a new weapon.
func switch_weapon(index: int) -> void:
	# 1. Check if the index is valid.
	if index < 0 or index >= weapon_data_array.size():
		printerr("WeaponManager: Invalid weapon index %d (array size: %d)" % [index, weapon_data_array.size()])
		return
	
	# Debug: Check array sizes
	if weapon_instances.size() != weapon_data_array.size():
		printerr("WeaponManager: Array size mismatch! weapon_instances: %d, weapon_data_array: %d" % [weapon_instances.size(), weapon_data_array.size()])
		return
	
	# 2. Hide the current weapon if one exists.
	if current_weapon_instance:
		current_weapon_instance.visible = false
		current_weapon_instance.set_process_mode(Node.PROCESS_MODE_DISABLED)

	# 3. Show and activate the new weapon.
	var weapon_instance = weapon_instances[index]
	if weapon_instance:
		current_weapon_instance = weapon_instance
		current_weapon_instance.visible = true
		current_weapon_instance.set_process_mode(Node.PROCESS_MODE_INHERIT)
		current_weapon_index = index
		
		# Emit current ammo state for UI update
		if current_weapon_instance.has_method("get_ammo_info"):
			var ammo_info = current_weapon_instance.get_ammo_info()
			if ammo_info.has("magazine") and ammo_info.has("total"):
				weapon_ammo_changed.emit(ammo_info.magazine, ammo_info.total)
		
		print("WeaponManager: Switched to weapon %d (%s)" % [index, current_weapon_instance.name])
		
		# Also update global crosshair node to reflect WeaponEquipped's configured crosshair
		get_tree().get_first_node_in_group("game-ui").crosshair.apply_data(current_weapon_instance.weapon_data.crosshair_data)
		
	else:
		printerr("WeaponManager: WeaponEquipped instance at index %d is null" % index)
		current_weapon_instance = null

# This function is called when the currently equipped weapon emits its "deal_damage" signal.
func _on_weapon_deal_damage(damage_amount: int, hit_point: Vector3, hit_normal: Vector3, collider: Object) -> void:
	# We simply re-emit the signal from the manager itself.
	# This keeps the player script from needing to know about the specific weapon instance.
	weapon_dealt_damage.emit(damage_amount, hit_point, hit_normal, collider)

# Forward ammunition signals from weapon to any listeners
func _on_weapon_ammo_changed(current_magazine: int, total_ammo: int) -> void:
	# Only the active weapon should be enabled and able to send signals
	weapon_ammo_changed.emit(current_magazine, total_ammo)

func _on_weapon_reload_started() -> void:
	# Only the active weapon should be enabled and able to send signals
	weapon_reload_started.emit()

func _on_weapon_reload_finished() -> void:
	# Only the active weapon should be enabled and able to send signals
	weapon_reload_finished.emit()

# Get weapon manager reference (for WeaponPickup to find us)
func get_weapon_manager() -> WeaponManager:
	return self

# WeaponEquipped Throwing/Pickup Functions

# Throw the current weapon
func throw_current_weapon(throw_force: Vector3 = Vector3.ZERO) -> bool:
	if not current_weapon_instance or not current_weapon_instance.weapon_data:
		return false
	
	var weapon_data = current_weapon_instance.weapon_data
	var throw_position = current_weapon_instance.global_position
	
	# Simple approach: just instantiate the weapon_pickup_scene and throw it
	if weapon_data.weapon_pickup_scene:
		var weapon_pickup = weapon_data.weapon_pickup_scene.instantiate()
		get_tree().root.add_child(weapon_pickup)
		weapon_pickup.global_position = throw_position
		
		# Set the weapon data on the pickup
		if weapon_pickup.has_method("set_weapon_data"):
			weapon_pickup.set_weapon_data(weapon_data)
		elif weapon_pickup.has_property("weapon_data"):
			weapon_pickup.weapon_data = weapon_data
		elif weapon_pickup.has_property("data"):
			weapon_pickup.data = weapon_data
		
		# Apply throw force if it's a RigidBody3D
		if weapon_pickup is RigidBody3D and throw_force != Vector3.ZERO:
			weapon_pickup.apply_central_impulse(throw_force)
		
		# Remove current weapon from manager
		remove_current_weapon()
		
		print("WeaponManager: Threw weapon %s" % weapon_data.weapon_name)
		return true
	else:
		print("WeaponManager: No weapon_pickup_scene for weapon %s" % weapon_data.weapon_name)
		return false

# Remove current weapon without throwing
func remove_current_weapon() -> void:
	if not current_weapon_instance:
		return
	
	var removed_index = current_weapon_index
	
	# Hide and disable current weapon
	current_weapon_instance.visible = false
	current_weapon_instance.set_process_mode(Node.PROCESS_MODE_DISABLED)
	current_weapon_instance.queue_free()
	
	# Remove from both arrays at the same index
	weapon_instances.remove_at(current_weapon_index)
	weapon_data_array.remove_at(current_weapon_index)
	
	# Reset current weapon
	current_weapon_instance = null
	current_weapon_index = -1
	
	# Switch to next available weapon
	_switch_to_next_available_weapon(removed_index)

# Switch to next available weapon after removal
func _switch_to_next_available_weapon(removed_index: int) -> void:
	if weapon_data_array.is_empty():
		print("WeaponManager: No weapons remaining")
		return
	
	# Try to switch to weapon at same index, or previous, or next
	var new_index = min(removed_index, weapon_data_array.size() - 1)
	switch_weapon(new_index)

# Pick up a weapon from weapon data
func pickup_weapon(weapon_data: WeaponData) -> bool:
	if not weapon_data:
		return false
	
	# Initialize ammo for the weapon data if not already done
	if weapon_data.uses_ammo and weapon_data.total_ammo == 0:
		weapon_data.initialize_ammo()
	
	# Check if we already have this weapon type
	for i in range(weapon_data_array.size()):
		var existing_data = weapon_data_array[i]
		if existing_data and existing_data.weapon_name == weapon_data.weapon_name:
			# Add ammo to existing weapon instead of picking up duplicate
			if existing_data.uses_ammo and weapon_data.uses_ammo:
				var ammo_to_add = weapon_data.total_ammo
				existing_data.total_ammo = min(existing_data.total_ammo + ammo_to_add, existing_data.max_total_ammo)
				print("WeaponManager: Added %d ammo to %s" % [ammo_to_add, weapon_data.weapon_name])
				
				# Update UI if this is current weapon
				if current_weapon_index == i and current_weapon_instance:
					if current_weapon_instance.has_method("get_ammo_info"):
						var ammo_info = current_weapon_instance.get_ammo_info()
						if ammo_info.has("magazine") and ammo_info.has("total"):
							weapon_ammo_changed.emit(ammo_info.magazine, ammo_info.total)
				
				return true
			else:
				print("WeaponManager: Already have weapon %s" % weapon_data.weapon_name)
				return false
	
	# Add new weapon to both arrays
	weapon_data_array.append(weapon_data)
	
	# Create weapon instance
	if weapon_data.weapon_equipped_scene:
		var weapon_instance = weapon_data.weapon_equipped_scene.instantiate()
		weapon_instance.shooter_body = shooter_body
		weapon_instance.custom_fire_origin = get_viewport().get_camera_3d() if shooter_body in get_tree().get_nodes_in_group("players") else null
		weapon_instance.friendly_group_name = shooter_body.friendly_group_name
		
		# Set weapon data
		if weapon_instance.has_method("set_weapon_data"):
			weapon_instance.set_weapon_data(weapon_data)
		
		# Add to scene tree but hide initially
		add_child(weapon_instance)
		weapon_instance.visible = false
		weapon_instance.set_process_mode(Node.PROCESS_MODE_DISABLED)
		
		# Connect signals
		weapon_instance.deal_damage.connect(_on_weapon_deal_damage)
		if weapon_instance.has_signal("ammo_changed"):
			weapon_instance.ammo_changed.connect(_on_weapon_ammo_changed)
		if weapon_instance.has_signal("reload_started"):
			weapon_instance.reload_started.connect(_on_weapon_reload_started)
		if weapon_instance.has_signal("reload_finished"):
			weapon_instance.reload_finished.connect(_on_weapon_reload_finished)
		
		# Add to instances array - IMPORTANT: Keep arrays in sync
		weapon_instances.append(weapon_instance)
		
		print("WeaponManager: Picked up weapon %s" % weapon_data.weapon_name)
		
		# Switch to picked up weapon if we don't have a current weapon
		if current_weapon_index == -1:
			switch_weapon(weapon_data_array.size() - 1)
		
		return true
	else:
		print("WeaponManager: No weapon_equipped_scene for weapon %s" % weapon_data.weapon_name)
		# Still add null to instances array to keep arrays in sync
		weapon_instances.append(null)
		return false

# Check if we can pickup a weapon
func can_pickup_weapon(weapon_data: WeaponData) -> bool:
	if not weapon_data:
		return false
	
	# Always allow pickup - either add ammo or pick up new weapon
	return true

# Get weapon throw direction based on camera/player forward
func get_throw_direction(throw_strength: float = 10.0) -> Vector3:
	var forward = -global_transform.basis.z  # Forward direction
	var up = Vector3.UP * 0.2  # Slight upward arc
	
	return (forward + up).normalized() * throw_strength
