# base_weapon.gd (Definitive Additive Recoil System)
class_name WeaponEquipped
extends Node3D

signal deal_damage(damage_amount: int, hit_point: Vector3, hit_normal: Vector3, collider: Object)
signal ammo_changed(current_magazine: int, total_ammo: int)
signal reload_started()
signal reload_finished()

# WeaponEquipped data resource that contains all persistent properties
var weapon_data: WeaponData

@export_group("Nodes")
@export var weapon_model: Node3D
@export var wall_check_ray: RayCast3D
@export var fire_ray: RayCast3D 
@export var custom_fire_origin: Node3D ## I want to use camera if player is using it

var _original_model_position: Vector3
var _original_model_rotation: Vector3

# Ammunition variables - these reference the weapon_data
var reload_timer: Timer

# We add this to exclude the player and weapon from the raycast.
# You should assign your player character node to this in the inspector.
@export var shooter_body: CharacterBody3D
@export var disable_friendly_fire: bool = true
@export var friendly_group_name: String = "ASSIGNED_BY_WEAPON_MANAGER"

var muzzle_flash: Node3D

func _ready() -> void:
	if weapon_model:
		_original_model_position = weapon_model.position
		_original_model_rotation = weapon_model.rotation
	
	# Initialize ammunition system
	_initialize_ammo_system()
	
	# Setup muzzle flash
	if weapon_data.muzzle_flash_scene and fire_ray:
		muzzle_flash = weapon_data.muzzle_flash_scene.instantiate()
		fire_ray.add_child(muzzle_flash)
		muzzle_flash.global_transform.origin = fire_ray.global_transform.origin

# Set weapon data - this should be called immediately after instantiation
func set_weapon_data(data: WeaponData) -> void:
	weapon_data = data
	# Initialize ammo system with the new data
	_initialize_ammo_system()

func get_weapon_data() -> WeaponData:
	return weapon_data

func _process(delta: float) -> void:
	if not weapon_model or not weapon_data:
		return
	
	# 1. Define the "target" resting state for this frame
	var target_position = _original_model_position
	var target_rotation = _original_model_rotation
	
	if wall_check_ray and wall_check_ray.is_colliding():
		var distance_to_wall = global_position.distance_to(wall_check_ray.get_collision_point())
		if distance_to_wall < weapon_data.retract_distance:
			target_position.z = _original_model_position.z + (weapon_data.retract_distance - distance_to_wall)

	# 2. Act as a spring: smoothly pull the current state towards the target state
	weapon_model.position = weapon_model.position.lerp(target_position, weapon_data.recovery_speed * delta)
	weapon_model.rotation = weapon_model.rotation.lerp(target_rotation, weapon_data.recovery_speed * delta)

func apply_recoil(kickback_amount: float, rotation_kick_degrees: Vector3) -> void:
	if not weapon_model: return
	
	weapon_model.position.z += kickback_amount
	weapon_model.rotate_object_local(Vector3.RIGHT, deg_to_rad(rotation_kick_degrees.x))
	weapon_model.rotate_object_local(Vector3.UP, deg_to_rad(rotation_kick_degrees.y))
	weapon_model.rotate_object_local(Vector3.FORWARD, deg_to_rad(rotation_kick_degrees.z))
	
	# Apply recoil in crosshair
	if get_tree().get_first_node_in_group("game-ui").crosshair:
		get_tree().get_first_node_in_group("game-ui").crosshair.recoil += 0.25


# AMMUNITION SYSTEM
func _initialize_ammo_system() -> void:
	if not weapon_data:
		return
		
	if weapon_data.uses_ammo:
		# Initialize ammunition from weapon data
		if weapon_data.current_magazine_ammo == 0:  # First time initialization
			weapon_data.initialize_ammo()
		
		# Create reload timer
		if not reload_timer:
			reload_timer = Timer.new()
			reload_timer.one_shot = true
			reload_timer.timeout.connect(_on_reload_finished)
			add_child(reload_timer)
		
		reload_timer.wait_time = weapon_data.reload_time
		
		# Emit initial ammo state
		ammo_changed.emit(weapon_data.current_magazine_ammo, weapon_data.total_ammo)

func can_fire() -> bool:
	if not weapon_data:
		return false
	if not weapon_data.uses_ammo:
		return true
	return weapon_data.current_magazine_ammo > 0 and not weapon_data.is_reloading

func consume_ammo() -> bool:
	if not weapon_data:
		return false
	if not weapon_data.uses_ammo:
		return true
	
	if weapon_data.current_magazine_ammo <= 0:
		return false
	
	weapon_data.current_magazine_ammo -= 1
	ammo_changed.emit(weapon_data.current_magazine_ammo, weapon_data.total_ammo)
	
	# Auto-reload if magazine is empty and we have ammo
	if weapon_data.current_magazine_ammo <= 0 and weapon_data.total_ammo > 0:
		start_reload()
	
	return true

func start_reload() -> void:
	if not weapon_data or not weapon_data.uses_ammo or weapon_data.is_reloading or weapon_data.total_ammo <= 0:
		return
	
	if weapon_data.current_magazine_ammo >= weapon_data.max_magazine_capacity:
		return  # Already full
	
	print("Reloading %s..." % weapon_data.weapon_name)
	weapon_data.is_reloading = true
	reload_started.emit()
	reload_timer.start()

func _on_reload_finished() -> void:
	if not weapon_data or not weapon_data.uses_ammo:
		return
	
	# Calculate how much ammo we need and can take
	var ammo_needed = weapon_data.max_magazine_capacity - weapon_data.current_magazine_ammo
	var ammo_to_transfer = min(ammo_needed, weapon_data.total_ammo)
	
	# Transfer ammo from total to magazine
	weapon_data.current_magazine_ammo += ammo_to_transfer
	weapon_data.total_ammo -= ammo_to_transfer
	
	weapon_data.is_reloading = false
	reload_finished.emit()
	ammo_changed.emit(weapon_data.current_magazine_ammo, weapon_data.total_ammo)
	
	print("Reload complete! Magazine: %d/%d, Total: %d" % [weapon_data.current_magazine_ammo, weapon_data.max_magazine_capacity, weapon_data.total_ammo])

func manual_reload() -> void:
	# Allow manual reload if not already reloading and magazine isn't full
	if weapon_data and not weapon_data.is_reloading and weapon_data.current_magazine_ammo < weapon_data.max_magazine_capacity and weapon_data.total_ammo > 0:
		start_reload()

func add_ammo(amount: int) -> void:
	if not weapon_data or not weapon_data.uses_ammo:
		return
	
	weapon_data.total_ammo = min(weapon_data.total_ammo + amount, weapon_data.max_total_ammo)
	ammo_changed.emit(weapon_data.current_magazine_ammo, weapon_data.total_ammo)

func get_ammo_info() -> Dictionary:
	if not weapon_data:
		return {}
	return {
		"magazine": weapon_data.current_magazine_ammo,
		"total": weapon_data.total_ammo,
		"max_magazine": weapon_data.max_magazine_capacity,
		"max_total": weapon_data.max_total_ammo,
		"is_reloading": weapon_data.is_reloading
	}


func fire_hitscan(damage_amount: int) -> void:
	# Check if we can fire (ammo check)
	if not can_fire():
		print("Cannot fire: No ammo or reloading")
		return
	
	# Consume ammo before firing
	if not consume_ammo():
		print("Cannot fire: Failed to consume ammo")
		return
	
	if not fire_ray:
		printerr("Fire Ray node not assigned in the inspector for ", self.name)
		return

	var space_state = get_world_3d().direct_space_state
	var ray_origin = fire_ray.global_transform.origin if custom_fire_origin == null else custom_fire_origin.global_transform.origin
	var ray_end = ray_origin + fire_ray.target_position.z * fire_ray.global_transform.basis.z  if custom_fire_origin == null else ray_origin + fire_ray.target_position.z * custom_fire_origin.global_transform.basis.z
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	
	var exclusions = [self]
	if shooter_body:
		exclusions.append(shooter_body.get_rid())
		if disable_friendly_fire:
			exclusions.append_array(get_tree().get_nodes_in_group(friendly_group_name))
	query.exclude = exclusions
	
	var result = space_state.intersect_ray(query)
	
	if not result:
		print("DEBUG: Raycast MISSED!")
	
	if result:
		var collider = result.collider
		var hit_point = result.position
		var hit_normal = result.normal
		
		# GAMEFEEL: Spawn visual effect INSTANTLY
		_spawn_impact_effect(hit_point, hit_normal, collider) # VFX at target
		muzzle_flash.start() # VFX at source/barrel

		# Now, handle the gameplay logic (damage, etc.)
		emit_signal("deal_damage", damage_amount, hit_point, hit_normal, collider)
		
		# Only apply damage if the target can take damage and isn't the shooter
		if collider and collider != shooter_body and collider.has_method("take_damage"):
			collider.take_damage(damage_amount)
			print("Dealt %d damage to: %s" % [damage_amount, collider.name])
		elif collider and collider == shooter_body:
			print("Prevented self-damage to: %s" % collider.name)
		elif collider:
			print("Hit object that can't take damage: %s" % collider.name)



# Virtual function for children to override.
func attack() -> void:
	pass

func _spawn_impact_effect(hit_point: Vector3, hit_normal: Vector3, collider: Object) -> void:
	if not weapon_data or weapon_data.impacts.is_empty():
		return # No impact effects defined for this weapon

	var specific_impact_scene: PackedScene = null
	var default_impact_scene: PackedScene = null

	# NEW, SIMPLIFIED LOGIC
	# In a single loop, find the default and check for a specific match.
	for impact_data in weapon_data.impacts:
		if not impact_data: continue # Skip if a slot in the array is empty

		# Check if this is the default impact. If so, store it.
		if impact_data.group_name.is_empty():
			default_impact_scene = impact_data.impact_scene
		
		# Check if this is a specific impact for the thing we hit.
		elif collider and collider.is_in_group(impact_data.group_name):
			specific_impact_scene = impact_data.impact_scene
			# We found the most specific match, so we can stop looking.
			break 
	
	# Decide which scene to use. Prioritize the specific one.
	var scene_to_spawn = specific_impact_scene if specific_impact_scene else default_impact_scene

	# Now, spawn the chosen scene.
	if scene_to_spawn:
		var impact_instance = scene_to_spawn.instantiate()
		get_tree().get_root().add_child(impact_instance)
		
		impact_instance.global_position = hit_point
		impact_instance.look_at(hit_point + hit_normal) 












func fire_projectile() -> void:
	# 1. Standard checks
	if not can_fire():
		print("Cannot fire: No ammo or reloading")
		return
	
	if not consume_ammo():
		print("Cannot fire: Failed to consume ammo")
		return

	# 2. Check for projectile data
	if not weapon_data.projectile_scene:
		printerr("No projectile_scene defined in WeaponData for ", self.name)
		return
		
	# 3. Instantiate the projectile
	var projectile_instance = weapon_data.projectile_scene.instantiate()
	
	# 4. Important: Pass data to the projectile
	projectile_instance.damage = weapon_data.damage
	projectile_instance.shooter_body = self.shooter_body

	# 5. Determine launch position and direction
	# Use the fire_ray's global transform as the spawn point and direction.
	var spawn_transform = fire_ray.global_transform
	
	# Add the projectile to the main scene tree, not as a child of the weapon
	get_tree().get_root().add_child(projectile_instance)
	projectile_instance.global_transform = spawn_transform
	
	# 6. Launch the projectile
	var launch_direction = -spawn_transform.basis.z # The forward direction
	projectile_instance.apply_central_impulse(launch_direction * weapon_data.projectile_launch_force)

	# GAMEFEEL
	# You can still have muzzle flash and recoil for a launcher
	if muzzle_flash:
		muzzle_flash.start()
	apply_recoil(weapon_data.recoil_kickback, weapon_data.recoil_rotation_degrees)
