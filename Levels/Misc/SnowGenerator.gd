# SnowfallController.gd
# Attach this script to a Node3D. It will automatically create and manage
# a GPU particle system to generate snow that follows the player.
# "Juice" is added through turbulence, random rotation, and size variation.

extends Node3D

## The target node for the snow to follow. Assign your player node here.
@export var player: Node3D

## How high above the player the snow should start falling.
@export var height_above_player: float = 10.0

## The size of the area above the player from which snow will spawn.
## A larger X and Z will make the snowfall feel more widespread.
@export var follow_area_size: Vector3 = Vector3(25, 1, 25)

## The total number of snowflakes visible at any time.
@export var snow_amount: int = 4000

## The base downward speed of the snow.
@export var fall_speed: float = 1.5

## How much the snow swirls. Higher values mean more chaotic, blizzard-like wind.
@export var turbulence_strength: float = 0.75

@export var noise_texture: NoiseTexture2D

var particles_node: GPUParticles3D


func _ready() -> void:
	# Safety Check
	if not player:
		push_error("Player node not assigned to SnowfallController! Snow will not be generated.")
		return

	# Create and Configure the Particle System
	particles_node = GPUParticles3D.new()
	add_child(particles_node)

	# Core Particle Properties
	particles_node.amount = snow_amount
	particles_node.lifetime = (height_above_player / fall_speed) * 1.5
	particles_node.process_material = _create_particle_material()
	particles_node.draw_pass_1 = _create_particle_mesh()
	
	# JUICE: Emit in World Space
	# This makes the player move *through* the snow, rather than the snow
	# moving perfectly with the player. It feels much more natural.
	particles_node.local_coords = false
	
	# FIX: Prevent Culling When Looking Down
	# We manually define a huge bounding box around the player. This tells the
	# renderer to keep the particles visible even if the emitter origin goes
	# off-screen (e.g., when the player looks down).
	var box_extents = Vector3(follow_area_size.x, height_above_player, follow_area_size.z)
	var aabb = AABB(-box_extents, box_extents * 2)
	particles_node.visibility_aabb = aabb

	particles_node.emitting = true


func _process(_delta: float) -> void:
	# Follow Logic
	if is_instance_valid(player):
		var player_pos = player.global_position
		self.global_position = Vector3(player_pos.x, player_pos.y + height_above_player, player_pos.z)


# Helper function to create the material that defines snow behavior
func _create_particle_material() -> ParticleProcessMaterial:
	var material = ParticleProcessMaterial.new()
	
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = follow_area_size

	material.direction = Vector3.DOWN
	material.spread = 15.0
	
	material.initial_velocity_min = fall_speed * 0.8
	material.initial_velocity_max = fall_speed * 1.2

	material.gravity = Vector3(0, -0.5, 0)
	
	# JUICE SETTINGS
	material.angle_min = -180
	material.angle_max = 180
	material.angular_velocity_min = -90
	material.angular_velocity_max = 90
	
	material.scale_min = 0.03
	material.scale_max = 0.08
	
	material.turbulence_enabled = true
	var turbulence = noise_texture
	
	return material


# Helper function to create the mesh that represents a single snowflake
func _create_particle_mesh() -> Mesh:
	var quad_mesh = QuadMesh.new()
	quad_mesh.size = Vector2(.1, .1)
	
	var material = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 1.0, 1.0, 0.8)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	
	quad_mesh.material = material
	return quad_mesh
