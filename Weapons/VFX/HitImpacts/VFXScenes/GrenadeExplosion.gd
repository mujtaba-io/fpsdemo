# blocky_explosion_vfx.gd
extends Node3D

# Node References
@onready var debris_particles: GPUParticles3D = $DebrisParticles
@onready var smoke_particles: GPUParticles3D = $SmokeParticles
@onready var flash_light: OmniLight3D = $FlashLight
@onready var shockwave: MeshInstance3D = $Shockwave
@onready var self_destruct_timer: Timer = $SelfDestructTimer

# Configuration
@export var flash_energy: float = 30.0
@export var flash_duration: float = 0.15
@export var shockwave_end_scale: float = 12.0
@export var shockwave_duration: float = 0.3

func _ready() -> void:
	# 1. Start the particle emitters immediately.
	debris_particles.emitting = true
	smoke_particles.emitting = true
	
	# 3. Start the timer that will eventually delete this scene.
	self_destruct_timer.start()
	
	# 4. Animate the flash and shockwave using a Tween for maximum juice.
	create_flash_and_shockwave_tween()

func create_flash_and_shockwave_tween() -> void:
	var tween = create_tween()
	# The flash and shockwave happen at the same time.
	tween.set_parallel(true)
	
	# Animate the light: bright to zero energy very quickly.
	tween.tween_property(flash_light, "light_energy", 0.0, flash_duration) \
		.from(flash_energy) \
		.set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_OUT)
		
	# Animate the shockwave scale: from nothing to its full size.
	shockwave.scale = Vector3.ZERO # Ensure it starts at size 0
	tween.tween_property(shockwave, "scale", Vector3.ONE * shockwave_end_scale, shockwave_duration) \
		.from(Vector3.ZERO) \
		.set_trans(Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_OUT)
	
	# Animate the shockwave fade: from fully opaque to fully transparent.
	# We target the material's color property directly.
	var shockwave_material = shockwave.get_active_material(0) as StandardMaterial3D
	var start_color = shockwave_material.albedo_color
	var end_color = Color(start_color, 0.0) # Same color, but with 0 alpha
	tween.tween_property(shockwave_material, "albedo_color", end_color, shockwave_duration) \
		.from(start_color) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN)

func _on_self_destruct_timer_timeout() -> void:
	# The effect has finished, now remove it from the scene.
	queue_free()
