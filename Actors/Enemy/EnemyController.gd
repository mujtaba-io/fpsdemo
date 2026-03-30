# EnemyController.gd - Smarter FPS AI
extends CharacterBody3D

# State Machine
enum State { IDLE, WANDER, PATROL, ALERT, COMBAT, GUARD }
var current_state = State.IDLE

# AI Behavior Modes
enum BehaviorMode { GUARD, WANDER, PATROL }

# AI Parameters
@export_group("Behavior")
@export var behavior_mode: BehaviorMode = BehaviorMode.WANDER
@export var move_speed: float = 3.0
@export var chase_speed: float = 4.5
@export var strafe_speed: float = 2.5
@export var turn_speed: float = 5.0
@export var gravity: float = 12.0
@export var guard_position_tolerance: float = 1.0 # How close to return to guard position
@export var guard_face_direction: Vector3 = Vector3.FORWARD # Direction to face when guarding (local space)

@export_group("Components")
@export var weapons_manager: WeaponManager
@export var health_component: Health

@export_group("Perception")
@export var detection_range: float = 30.0
@export var fov_angle: float = 90.0 # Field of view in degrees
@export var lose_sight_time: float = 3.0 # How long to stay alert after losing player

@export_group("Combat")
@export var optimal_attack_distance: float = 15.0
@export var aim_sway_amount: float = 0.1 # Adds slight inaccuracy

@export_group("Friendly Fire Group")
@export var friendly_group_name: String = "enemies"

# Node References
@onready var head: Node3D = $Head
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var attack_timer: Timer = $AttackTimer
@onready var alert_cooldown: Timer = $AlertCooldown
@onready var wander_timer: Timer = $WanderTimer
@onready var strafe_timer: Timer = $StrafeTimer

# Pathfinding & State Variables
var path_node: Path3D
var current_path_point_index: int = 0
var player_ref: CharacterBody3D = null
var last_known_player_position: Vector3
var strafe_direction: Vector3 = Vector3.RIGHT
var initial_position: Vector3 # Spawn position for guard duty
var initial_rotation: Vector3 # Spawn rotation for guard duty
var is_returning_to_duty: bool = false
var is_dead: bool = false


func _ready() -> void:
	add_to_group("enemies", true) # Persist group membership across scene loads
	add_to_group("mortals", true)
	
	# Store initial position and rotation for guard duty
	initial_position = global_position
	initial_rotation = rotation
	
	if not weapons_manager:
		push_error("Enemy '%s' has no Weapons Manager assigned!" % name)

	# Setup timers
	alert_cooldown.wait_time = lose_sight_time
	strafe_timer.timeout.connect(_on_strafe_timer_timeout)
	wander_timer.timeout.connect(_on_wander_timer_timeout)
	
	# Connect health system signals
	if health_component:
		health_component.died.connect(_on_enemy_died)
		health_component.health_changed.connect(_on_health_changed)
	
	# Determine initial state based on behavior mode
	match behavior_mode:
		BehaviorMode.GUARD:
			_transition_to_state(State.GUARD)
		BehaviorMode.PATROL:
			path_node = get_node_or_null("Path3D")
			if path_node and path_node.curve.get_point_count() > 0:
				_transition_to_state(State.PATROL)
			else:
				push_warning("Enemy '%s' set to PATROL mode but no valid Path3D child found. Switching to GUARD mode." % name)
				behavior_mode = BehaviorMode.GUARD
				_transition_to_state(State.GUARD)
		BehaviorMode.WANDER:
			_transition_to_state(State.WANDER)


func _physics_process(delta: float) -> void:
	if is_dead:
		# Dead enemy physics - stop all movement and just apply gravity
		velocity.x = 0
		velocity.z = 0
		if not is_on_floor():
			velocity.y -= gravity * delta
		move_and_slide()
		return
		
	# 1. Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# 2. Perception and State Transitions
	_perceive_player()
	_update_state_machine()

	# 3. Execute State Logic
	var target_velocity := Vector3.ZERO
	match current_state:
		State.IDLE:
			pass # Do nothing, wait for wander timer
		State.GUARD:
			target_velocity = _get_guard_velocity()
			_apply_guard_rotation(delta)
		State.WANDER, State.PATROL, State.ALERT:
			target_velocity = _get_nav_path_velocity()
			_apply_body_rotation(target_velocity, delta)
		State.COMBAT:
			target_velocity = _get_combat_velocity(delta)
			_apply_body_rotation((player_ref.global_position - global_position), delta)
			_aim_at_target(player_ref, delta)
			_shoot_at_target()

	# 4. Apply Movement
	velocity.x = target_velocity.x
	velocity.z = target_velocity.z
	move_and_slide()

#
# PERCEPTION & STATE MANAGEMENT
#

func _perceive_player():
	var potential_player = _find_player_in_vicinity()
	if is_instance_valid(potential_player):
		player_ref = potential_player
		last_known_player_position = player_ref.get_aim_target_position() if player_ref.has_method("get_aim_target_position") else player_ref.global_position
	else:
		player_ref = null

func _update_state_machine():
	match current_state:
		State.IDLE, State.WANDER, State.PATROL, State.ALERT, State.GUARD:
			if player_ref:
				_transition_to_state(State.COMBAT)
		
		State.COMBAT:
			if not player_ref:
				_transition_to_state(State.ALERT)

func _transition_to_state(new_state: State):
	if current_state == new_state: return
	
	# print("%s -> %s" % [name, State.keys()[new_state]]) # For debugging
	current_state = new_state
	
	match new_state:
		State.GUARD:
			# If not at guard position, navigate there
			if global_position.distance_to(initial_position) > guard_position_tolerance:
				nav_agent.target_position = initial_position
				is_returning_to_duty = true
			else:
				is_returning_to_duty = false
		State.PATROL:
			   # NEW: Start patrolling from the first point on the path.
			current_path_point_index = 0
			_update_patrol_target()
		State.WANDER:
			# If we enter wander, immediately find a new point instead of waiting
			_on_wander_timer_timeout()
		State.ALERT:
			nav_agent.target_position = last_known_player_position
			alert_cooldown.start()
		State.COMBAT:
			# Immediately stop any navigation pathfinding
			nav_agent.target_position = global_position 
			strafe_timer.start() # Start strafing
		_:
			pass # Other states don't need special entry logic

#
# MOVEMENT & ACTION LOGIC
#


# Sets the navigation agent's target to the current patrol point on the Path3D.
func _update_patrol_target() -> void:
	if not path_node or path_node.curve.get_point_count() == 0:
		push_warning("Cannot update patrol target: Invalid Path3D or empty curve on '%s'. Switching to GUARD mode." % name)
		_transition_to_state(State.GUARD)
		return

	# Ensure the index loops around if it goes past the end
	if current_path_point_index >= path_node.curve.get_point_count():
		current_path_point_index = 0
	
	# The points in Path3D's curve are local to the Path3D node.
	# We need to convert the local point position to a global world position.
	var local_point_pos = path_node.curve.get_point_position(current_path_point_index)
	var global_target_pos = path_node.to_global(local_point_pos)
	
	nav_agent.target_position = global_target_pos


func _get_nav_path_velocity() -> Vector3:
	#
	if nav_agent.is_navigation_finished():
		if current_state == State.PATROL:
			# We've reached a patrol point, so we advance to the next one.
			current_path_point_index += 1 
			_update_patrol_target()
			# A new target is set. Return zero this frame to let the nav agent
			# calculate the new path. Movement will resume on the next frame.
			return Vector3.ZERO
		
		if current_state == State.ALERT:
			# Return to original behavior mode after alert
			match behavior_mode:
				BehaviorMode.GUARD:
					_transition_to_state(State.GUARD)
				BehaviorMode.PATROL:
					_transition_to_state(State.PATROL)
				BehaviorMode.WANDER:
					_transition_to_state(State.WANDER)
		
		# For WANDER, ALERT, etc., if the path is finished, stop moving.
		return Vector3.ZERO
	
	var direction = (nav_agent.get_next_path_position() - global_position).normalized()
	
	# Smooth arrival for wandering and alert states
	if current_state == State.WANDER or current_state == State.ALERT:
		var distance_to_target = global_position.distance_to(nav_agent.target_position)
		var slow_down_distance = 3.0
		if distance_to_target < slow_down_distance:
			var speed_factor = max(distance_to_target / slow_down_distance, 0.2)
			return direction * move_speed * speed_factor
	
	# For PATROL, use the standard move speed
	return direction * move_speed

func _get_combat_velocity(_delta: float) -> Vector3:
	var direction_to_player = (player_ref.global_position - global_position)
	var distance_to_player = direction_to_player.length()
	
	var combat_velocity = Vector3.ZERO
	
	# Move closer if too far, or back up if too close
	if distance_to_player > optimal_attack_distance:
		combat_velocity = direction_to_player.normalized() * chase_speed
	
	# Add strafing movement
	combat_velocity += strafe_direction * strafe_speed
	
	return combat_velocity

func _get_guard_velocity() -> Vector3:
	# If returning to duty position
	if is_returning_to_duty:
		var distance_to_position = global_position.distance_to(initial_position)
		if distance_to_position <= guard_position_tolerance:
			is_returning_to_duty = false
			return Vector3.ZERO
		
		# Get direction and apply smooth movement
		var direction = (nav_agent.get_next_path_position() - global_position).normalized()
		
		# Slow down as we approach the target position for smoother arrival
		var speed_factor = min(distance_to_position / guard_position_tolerance, 1.0)
		speed_factor = max(speed_factor, 0.3) # Minimum speed to prevent stopping too early
		
		return direction * move_speed * speed_factor
	else:
		return Vector3.ZERO # Stand still when on duty

func _apply_guard_rotation(delta: float):
	if is_returning_to_duty:
		# Face the direction we're moving when returning to position (only horizontal rotation)
		var next_position = nav_agent.get_next_path_position()
		var movement_direction = next_position - global_position
		# Flatten the direction to avoid upward tilt
		movement_direction.y = 0
		movement_direction = movement_direction.normalized()
		
		if movement_direction.length_squared() > 0.01:
			var target_basis = Transform3D().looking_at(movement_direction, Vector3.UP).basis
			self.global_transform.basis = self.global_transform.basis.slerp(target_basis, turn_speed * delta)
	else:
		# Return to the original spawn rotation when on duty
		var target_rotation = initial_rotation
		var target_transform = Transform3D()
		target_transform = target_transform.rotated(Vector3.UP, target_rotation.y)
		target_transform = target_transform.rotated(Vector3.RIGHT, target_rotation.x)
		target_transform = target_transform.rotated(Vector3.FORWARD, target_rotation.z)
		
		self.global_transform.basis = self.global_transform.basis.slerp(target_transform.basis, turn_speed * delta)

func _apply_body_rotation(look_direction: Vector3, delta: float):
	var horizontal_dir = look_direction * Vector3(1, 0, 1)
	if horizontal_dir.length_squared() > 0.01:
		var target_basis = Transform3D().looking_at(horizontal_dir.normalized(), Vector3.UP).basis
		self.global_transform.basis = self.global_transform.basis.slerp(target_basis, turn_speed * delta)

func _aim_at_target(target: Node3D, _delta: float):
	# Get the precise target position from the player character
	var aim_position: Vector3
	if target.has_method("get_aim_target_position"):
		aim_position = target.get_aim_target_position()
	else:
		aim_position = target.global_position # Fallback
	
	# Add some slight sway/inaccuracy to the aim
	var time = Time.get_ticks_msec() * 0.001
	var sway = Vector3(
		sin(time * 2.1) * aim_sway_amount,
		cos(time * 1.8) * aim_sway_amount,
		0
	)
	# Use the new aim_position for targeting
	var target_pos = aim_position + sway
	
	# Aim the head directly at the target
	head.look_at(target_pos, Vector3.UP)
	# The body rotation is handled separately, so we negate the body's influence on the head's Y rotation
	head.rotation.y = 0

func _shoot_at_target():
	if weapons_manager and attack_timer.is_stopped():
		weapons_manager.attack()
		attack_timer.start()

#
# HELPER & UTILITY FUNCTIONS
#

func _find_player_in_vicinity() -> CharacterBody3D:
	var players = get_tree().get_nodes_in_group("players")
	if players.is_empty(): return null
	
	var player = players[0] # Assuming single player
	
	# 1. Check distance (uses player origin, which is fine for a broad check)
	if global_position.distance_to(player.global_position) > detection_range:
		return null
		
	# 2. Check Field of View (FOV)
	var vector_to_player = (player.global_position - global_position).normalized()
	var forward_vector = -self.global_transform.basis.z
	if forward_vector.dot(vector_to_player) < cos(deg_to_rad(fov_angle / 2)):
		return null
		
	# 3. Check Line of Sight (LOS) using the new target point
	var los_target_pos: Vector3
	
	# Check if the player provides a specific target point.
	if player.has_method("get_aim_target_position"):
		los_target_pos = player.get_aim_target_position()
	else:
		# Fallback to the old method if the function doesn't exist
		var player_head = player.get_node_or_null("Head")
		los_target_pos = player.global_position if not player_head else player_head.global_position

	var space_state = get_world_3d().direct_space_state
	# Use the determined los_target_pos for the raycast
	var query = PhysicsRayQueryParameters3D.create(head.global_position, los_target_pos, 1)
	var result = space_state.intersect_ray(query)
	
	return player if result and result.collider == player else null

func _pick_random_wander_point():
	var wander_radius = 15.0
	var random_dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	var target_point = global_position + random_dir * wander_radius
	
	# Ensure the point is on the navmesh
	nav_agent.target_position = NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, target_point)

func take_damage(amount: int):
	if health_component and not is_dead:
		health_component.take_damage(amount)
		
		# If shot while not in combat, instantly become alert and know player's position
		if current_state != State.COMBAT:
			var players = get_tree().get_nodes_in_group("players")
			if not players.is_empty():
				last_known_player_position = players[0].global_position
				_transition_to_state(State.ALERT)

func _on_enemy_died():
	print("Enemy %s has died!" % name)
	is_dead = true
	current_state = null # Prevents further logic execution
	
	# Disable AI components
	nav_agent.set_process_mode(Node.PROCESS_MODE_DISABLED)
	if weapons_manager:
		weapons_manager.set_process_mode(Node.PROCESS_MODE_DISABLED)
	
	# Start death animation
	_start_death_animation()

func _on_health_changed(current_health: int, max_health: int):
	print("Enemy %s health: %d/%d" % [name, current_health, max_health])

func _start_death_animation():
	# Create death animation - fall to ground and disappear after delay
	var death_tween = create_tween()
	death_tween.set_parallel(true)
	
	# Fall backward
	death_tween.tween_property(self, "rotation:x", deg_to_rad(-90), 1.0)
	
	# After falling, wait and then fade out
	death_tween.chain().tween_interval(3.0)
	death_tween.chain().tween_callback(queue_free)

func _die():
	# Legacy function - now handled by health system
	if health_component:
		health_component.take_damage(health_component.current_health)

#
# TIMER CALLBACKS
#

func _on_strafe_timer_timeout():
	# Flip strafe direction, add a small random chance to keep same direction
	if randf() > 0.2:
		strafe_direction = strafe_direction.rotated(Vector3.UP, PI) # 180 degree turn
	strafe_timer.wait_time = randf_range(1.0, 3.0) # Strafe for a random duration
	strafe_timer.start()

func _on_wander_timer_timeout():
	if current_state == State.WANDER or current_state == State.IDLE:
		_pick_random_wander_point()
		_transition_to_state(State.WANDER)

func _on_alert_cooldown_timeout():
	# If the alert timer runs out and we haven't found the player, go back to normal behavior.
	if current_state == State.ALERT:
		match behavior_mode:
			BehaviorMode.GUARD:
				_transition_to_state(State.GUARD)
			BehaviorMode.PATROL:
				if path_node and path_node.curve.get_point_count() > 0:
					_transition_to_state(State.PATROL)
				else:
					_transition_to_state(State.GUARD) # Fallback to guard if no path
			BehaviorMode.WANDER:
				_transition_to_state(State.WANDER)
