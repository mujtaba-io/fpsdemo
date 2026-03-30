extends CharacterBody3D

# BLOCKY FPS CONTROLLER
# Controls are "snappy" and rigid to match a blocky aesthetic.
# Full body rotates, movement is instant, no smoothing.

# Movement Parameters
@export_group("Movement")
@export var walk_speed = 5.0
@export var sprint_speed = 8.0
@export var crouch_speed = 2.5
@export var jump_strength = 5.0
@export var gravity = 9.8

# Look & Feel Parameters
@export_group("Look & Feel")
@export var mouse_sensitivity = 0.002
# Head Bob
@export var bob_freq = 2.0
@export var bob_amp = 0.06
# FOV
@export var base_fov = 75.0
@export var sprint_fov = 85.0


@export_group("Components")
@export var weapons_manager: WeaponManager
@export var interactor: Interactor
@export var health_component: Health

@export_group("Aim & Damage")
@export var aim_target: Marker3D # For AI enemies to aim at (instead of aiming to origin of player)

@export_group("Friendly Fire Group")
@export var friendly_group_name: String = "players"

# Node References
@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var uncrouch_check = $UncrouchCheck


# Private Variables
var is_crouching = false
var bob_time = 0.0
var crouch_depth = -0.6
var stand_height = 1.2
var is_dead = false


func _ready():
	add_to_group("players")
	add_to_group("mortals")
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	camera.fov = base_fov
	
	# Make sure the weapon_manager exists before connecting.
	if weapons_manager:
		# Connect to the manager's signal, NOT the individual weapon's signal.
		weapons_manager.weapon_dealt_damage.connect(_on_weapon_deal_damage)
		
		# Connect to ammunition signals
		weapons_manager.weapon_ammo_changed.connect(_on_weapon_ammo_changed)
		weapons_manager.weapon_reload_started.connect(_on_weapon_reload_started)
		weapons_manager.weapon_reload_finished.connect(_on_weapon_reload_finished)
	
	# Connect health system signals
	if health_component:
		health_component.died.connect(_on_player_died)
		health_component.health_changed.connect(_on_health_changed)
		
		init_health_ui.call_deferred(health_component)
		
	
	# Connect interactor signals
	if interactor:
		interactor.interactable_detected.connect(_on_interactor_detected_interactable)
		interactor.interactable_lost.connect(_on_interactor_lost_interactable)
		# Connect to interaction completion for weapon pickup
		interactor.interaction_available.connect(_on_interactor_interaction_available)


# Function just to delay assignment so it doesnt gets error since groups are not yet initialized in _ready
func init_health_ui(health_component: Health):
	get_tree().get_first_node_in_group("game-ui").update_health(health_component.current_health, health_component.max_health)


func _input(event):
	if is_dead:
		return
		
	# Debug commands (remove in production)
	if event.is_action_pressed("ui_cancel"):  # ESC key for debug
		_debug_ammo_info()
		
	if event is InputEventMouseMotion:
			   # MOUSE LOOK
		# Rotate the entire Player body left/right (Y-axis) for a classic feel.
		self.rotate_y(-event.relative.x * mouse_sensitivity)
		
		# Rotate only the Camera up/down (X-axis).
		var head_rotation = head.rotation.x - event.relative.y * mouse_sensitivity
		head.rotation.x = clamp(head_rotation, -PI/2, PI/2)

	# Handle all weapon-related input
	if event.is_action_pressed("fire"):
		if weapons_manager:
			weapons_manager.attack()
	
	if event.is_action_pressed("reload"):
		if weapons_manager:
			weapons_manager.reload_current_weapon()
	
	if event.is_action_pressed("throw_weapon"):
		if weapons_manager:
			weapons_manager.throw_weapon_with_force()
	
	if event.is_action_pressed("weapon_scroll_up"):
		if weapons_manager:
			weapons_manager.switch_to_next_weapon()
	elif event.is_action_pressed("weapon_scroll_down"):
		if weapons_manager:
			weapons_manager.switch_to_previous_weapon()


func _physics_process(delta):
	if is_dead:
		# Dead player physics - just apply gravity
		if not is_on_floor():
			velocity.y -= gravity * delta
		move_and_slide()
		return
		
	# State Updates
	handle_crouch()
	var is_sprinting = handle_sprint()
	
	# Movement Logic
	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# Handle jumping (instant velocity change)
	if Input.is_action_just_pressed("ui_accept") and is_on_floor() and not is_crouching:
		velocity.y = jump_strength
	
	# Get input direction
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	# Direction is based on the PLAYER's rotation, not the head's.
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# Determine target speed
	var target_speed = walk_speed
	if is_sprinting:
		target_speed = sprint_speed
	elif is_crouching:
		target_speed = crouch_speed
	
	# Apply movement (SNAPPY - NO ACCELERATION)
	# Velocity is set directly for instant start/stop.
	velocity.x = direction.x * target_speed
	velocity.z = direction.z * target_speed
	
	# Apply velocity
	move_and_slide()


func handle_crouch():
	if Input.is_action_just_pressed("crouch"):
		# Only allow standing up if the space is clear
		if is_crouching and uncrouch_check.is_colliding():
			return # Don't stand up
			
		is_crouching = !is_crouching
		# INSTANT crouch/stand height change. No tween.
		head.position.y = stand_height + crouch_depth if is_crouching else stand_height

func handle_sprint() -> bool:
	# Can only sprint when moving forward, not crouching, and on the floor
	var input_dir_y = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down").y
	var can_sprint = Input.is_action_pressed("sprint") and is_on_floor() and input_dir_y < 0 and not is_crouching
	
	# INSTANT FOV change. No tween.
	camera.fov = sprint_fov if can_sprint else base_fov
	return can_sprint










# This function receives the damage signal from the WeaponManager.
func _on_weapon_deal_damage(damage_amount: int, hit_point: Vector3, hit_normal: Vector3, collider: Object) -> void:
	print("Player weapon hit target with %d damage!" % damage_amount)
	
	# The weapon system already handles self-damage prevention and target validation
	# No need to duplicate the logic here - just log the event



# This function allows the player to be damaged by enemies.
func take_damage(amount: int) -> void:
	if health_component and not is_dead:
		health_component.take_damage(amount)

func _on_player_died():
	print("Player has died!")
	is_dead = true
	
	# Release mouse capture
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Disable weapons
	if weapons_manager:
		weapons_manager.set_process_mode(Node.PROCESS_MODE_DISABLED)
	
	# Start death animation - fall to ground
	_start_death_animation()

func _on_health_changed(current_health: int, max_health: int):
	print("Player health: %d/%d (%.1f%%)" % [current_health, max_health, (float(current_health) / max_health) * 100])
	get_tree().get_first_node_in_group("game-ui").update_health(current_health, max_health)

func _start_death_animation():
	# Create a tween to make the player fall
	var death_tween = create_tween()
	death_tween.set_parallel(true)
	
	# Tilt the head down to simulate falling
	death_tween.tween_property(head, "rotation:x", deg_to_rad(90), 1.5)
	
	# Move the camera down slightly to simulate collapse
	death_tween.tween_property(head, "position:y", crouch_depth * 2, 2.0)



func get_aim_target_position() -> Vector3:
	# This function allows other objects, like the AI,
	# to get the precise global position to shoot at.
	return aim_target.global_position

func get_current_weapon_ammo() -> Dictionary:
	if weapons_manager:
		return weapons_manager.get_current_weapon_ammo_info()
	return {}

func add_ammo_to_current_weapon(amount: int) -> void:
	if weapons_manager and weapons_manager.current_weapon_instance:
		if weapons_manager.current_weapon_instance.has_method("add_ammo"):
			weapons_manager.current_weapon_instance.add_ammo(amount)

func _debug_ammo_info() -> void:
	print("DEBUG - All WeaponEquipped Ammo States")
	if weapons_manager and weapons_manager.has_method("get_all_weapon_ammo_info"):
		var all_ammo_info = weapons_manager.get_all_weapon_ammo_info()
		for info in all_ammo_info:
			if info.has("error"):
				print("WeaponEquipped %d (%s): %s" % [info.weapon_index, info.weapon_name, info.error])
			elif info.has("magazine"):
				var current_marker = " <- CURRENT" if info.weapon_index == weapons_manager.current_weapon_index else ""
				print("WeaponEquipped %d (%s): Magazine %d/%d, Total %d/%d, Reloading: %s%s" % [
					info.weapon_index, 
					info.weapon_name,
					info.magazine, 
					info.max_magazine, 
					info.total, 
					info.max_total, 
					info.is_reloading,
					current_marker
				])
			else:
				print("WeaponEquipped %d (%s): No ammo system (melee)" % [info.weapon_index, info.weapon_name])
	else:
		print("DEBUG - No weapons manager or ammo info method available")
	print("")

# AMMUNITION SYSTEM HANDLERS

func _on_weapon_ammo_changed(current_magazine: int, total_ammo: int) -> void:
	print("Ammo: %d/%d" % [current_magazine, total_ammo])
	get_tree().get_first_node_in_group("game-ui").update_weapon(
		weapons_manager.current_weapon_instance.weapon_data.weapon_name,
		current_magazine,
		total_ammo
	)

func _on_weapon_reload_started() -> void:
	print("Reloading weapon...")
	pass

func _on_weapon_reload_finished() -> void:
	print("Reload complete!")
	pass






# Interaction System Functions

# Called when interactor detects an interactable
func _on_interactor_detected_interactable(interactable: Interactable) -> void:
	get_tree().get_first_node_in_group("game-ui").show_prompt(interactable.interaction_prompt)

# Called when interactor loses sight of interactable
func _on_interactor_lost_interactable() -> void:
	get_tree().get_first_node_in_group("game-ui").hide_prompt()

# Called when interactor has an interaction available (handles weapon pickup automatically)
func _on_interactor_interaction_available(interactable: Interactable) -> void:
	# Check if this is a weapon pickup
	if interactable and interactable.get_parent().has_method("get_weapon_data"):
		var weapon_world = interactable.get_parent()
		var weapon_data = weapon_world.get_weapon_data()
		if weapon_data:
			# This will be called when player presses interact near a weapon
			# The actual pickup will be handled by the weapon world's interaction system
			pass
