# knife.gd
extends WeaponEquipped

@export_group("Stats")
@export var hit_area: Area3D

var can_damage: bool = false
@onready var swing_timer: Timer = $SwingTimer
var slash_tween: Tween
var original_rotation: Vector3

func _ready() -> void:
	super._ready()
	
	if hit_area:
		hit_area.body_entered.connect(_on_hit_area_body_entered)
	if weapon_model:
		original_rotation = weapon_model.rotation_degrees

# This is our knife "swing".
func attack() -> void:
	if not weapon_data:
		return
		
	# We can only swing if the timer isn't running and animation isn't playing.
	if not swing_timer.is_stopped() or (slash_tween and slash_tween.is_running()):
		return

	print("Knife: SWOOSH!")
	
	# Start Gameplay Logic
	can_damage = true
	hit_area.monitoring = true
	swing_timer.start()

	# Perform Slash Animation
	if weapon_model:
		if slash_tween:
			slash_tween.kill()

		slash_tween = create_tween()
		slash_tween.set_parallel(true)
		slash_tween.set_trans(Tween.TRANS_CUBIC)
		slash_tween.set_ease(Tween.EASE_OUT)
		
		# The SLASH
		slash_tween.tween_property(weapon_model, "position:z", weapon_model.position.z + weapon_data.slash_lunge_distance, weapon_data.slash_duration)
		slash_tween.tween_property(weapon_model, "rotation_degrees", original_rotation + weapon_data.slash_rotation_degrees, weapon_data.slash_duration)
		
		# The RETURN
		slash_tween.set_parallel(false)
		var return_tween = slash_tween.chain()
		return_tween.set_trans(Tween.TRANS_SINE)
		return_tween.set_ease(Tween.EASE_OUT)
		
		return_tween.tween_property(weapon_model, "position:z", _original_model_position.z, weapon_data.return_duration)
		return_tween.parallel().tween_property(weapon_model, "rotation_degrees", original_rotation, weapon_data.return_duration)


# Called when the swing duration is over.
func _on_swing_timer_timeout() -> void:
	can_damage = false
	hit_area.monitoring = false

# Called when something enters the knife's damage area.
func _on_hit_area_body_entered(body: Node3D) -> void:
	if not weapon_data:
		return
		
	if can_damage and body != shooter_body:  # Don't damage the shooter
		print("Knife hit: ", body.name)
		can_damage = false # Prevent multi-hits
		
		# Apply damage directly if the body can take damage
		if body.has_method("take_damage"):
			body.take_damage(weapon_data.damage)
			print("Dealt %d damage to: %s" % [weapon_data.damage, body.name])
		else:
			print("Hit object that can't take damage: %s" % body.name)
			
		emit_signal("deal_damage", weapon_data.damage, body.global_position, -global_transform.basis.z, body)
