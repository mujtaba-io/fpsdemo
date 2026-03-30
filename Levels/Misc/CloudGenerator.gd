# This script procedurally generates and animates Minecraft-style clouds.
# It uses MultiMeshInstance3D for high performance and FastNoiseLite for organic shapes.
# It's a @tool script, so you can see and configure the clouds directly in the Godot editor.
#
# HOW TO USE:
# 1. Attach this script to a Node3D.
# 2. Adjust the parameters in the Inspector.
# 3. To spawn clouds in the editor, check the "Regenerate Clouds" checkbox.

@tool
extends Node3D

#
#  Export Variables - Your control panel for the clouds!
#

@export_group("Generation", "gen_")
## When checked in the editor, this will clear and respawn all clouds.
@export var gen_regenerate_clouds: bool = false:
	set(value):
		if value:
			_generate_all_clouds()
			# Set back to false to act like a button
			set_block_signals(true)
			gen_regenerate_clouds = false
			set_block_signals(false)

## The number of cloud clusters to create.
@export var gen_cloud_count: int = 50
## The size of the area (X and Z) over which clouds will spawn and drift.
@export var gen_spawn_area_size: Vector2 = Vector2(1000, 1000)
## The minimum and maximum height (Y) for the clouds.
@export var gen_min_height: float = 80.0
@export var gen_max_height: float = 100.0

@export_group("Cloud Shape", "shape_")
## The size of each individual block that makes up a cloud.
@export var shape_cloud_block_size: float = 4.0
## The maximum dimensions of a single cloud cluster, in blocks (e.g., 8x4x8 blocks).
@export var shape_cluster_dimensions: Vector3i = Vector3i(12, 5, 12)
## Controls how "full" a cloud is. 0.0 is empty, 1.0 is a solid block. Around 0.6 is good.
@export var shape_density: float = 0.6
## The "zoom" level for the noise. Smaller values create larger, smoother cloud features.
@export var shape_noise_scale: float = 0.2
## Adds more detail to the noise. Higher values create more complex cloud shapes.
@export var shape_noise_octaves: int = 3

@export_group("Animation & Appearance", "anim_")
## The direction and speed at which the clouds drift.
@export var anim_cloud_speed: Vector3 = Vector3(5.0, 0.0, 1.0)
## The color of the clouds.
@export var anim_cloud_color: Color = Color.WHITE

#
#  Private Variables
#

# We use one shared mesh and material for all clouds for efficiency.
var _cloud_block_mesh: BoxMesh
var _cloud_material: StandardMaterial3D

var _noise: FastNoiseLite
var _cloud_clusters: Array[Node3D]

#
#  Godot Engine Callbacks
#

func _ready() -> void:
	# At runtime, generate the clouds automatically.
	if not Engine.is_editor_hint():
		_generate_all_clouds()

func _process(delta: float) -> void:
	# We don't want clouds moving in the editor, only in the running game.
	if Engine.is_editor_hint():
		return
	
	_move_clouds(delta)
	
#
#  Cloud Generation
#

# Main function to clear old clouds and generate new ones.
func _generate_all_clouds() -> void:
	_clear_clouds()
	_initialize_shared_resources()
	
	for i in range(gen_cloud_count):
		var cloud_cluster := _create_cloud_cluster()
		add_child(cloud_cluster)
		_cloud_clusters.append(cloud_cluster)

# Delete any previously generated cloud nodes.
func _clear_clouds() -> void:
	for cloud in _cloud_clusters:
		if is_instance_valid(cloud):
			cloud.queue_free()
	_cloud_clusters.clear()
	
	# Safety check for editor: ensure all old cloud nodes are gone.
	for child in get_children():
		if child.name.begins_with("CloudCluster_"):
			child.queue_free()

# Create the shared Mesh and Material to be used by all cloud blocks.
func _initialize_shared_resources() -> void:
	_cloud_block_mesh = BoxMesh.new()
	_cloud_block_mesh.size = Vector3.ONE * shape_cloud_block_size
	
	_cloud_material = StandardMaterial3D.new()
	_cloud_material.albedo_color = anim_cloud_color
	_cloud_material.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED # For a flat, bright look.
	_cloud_material.cull_mode = BaseMaterial3D.CULL_DISABLED # Helps with thin clouds.

# Create a single complete cloud cluster.
func _create_cloud_cluster() -> Node3D:
	# Each cloud is a parent Node3D with a MultiMeshInstance3D child.
	# This allows us to move the entire cloud easily.
	var cluster_parent = Node3D.new()
	cluster_parent.name = "CloudCluster_" + str(randi())

	var mmi = MultiMeshInstance3D.new()
	var multimesh = MultiMesh.new()
	
	# Configure the MultiMesh
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _cloud_block_mesh
	
	# Generate the transforms (positions) for each block in this cloud
	var block_transforms := _generate_cloud_shape()
	multimesh.instance_count = block_transforms.size()
	
	var i: int = 0
	for transform in block_transforms:
		multimesh.set_instance_transform(i, transform)
		i += 1
		
	mmi.multimesh = multimesh
	
	# *** THIS IS THE CORRECTED LINE ***
	mmi.material_override = _cloud_material
	
	cluster_parent.add_child(mmi)
	
	# Set a random starting position for the cloud cluster.
	cluster_parent.position = Vector3(
		randf_range(-gen_spawn_area_size.x / 2.0, gen_spawn_area_size.x / 2.0),
		randf_range(gen_min_height, gen_max_height),
		randf_range(-gen_spawn_area_size.y / 2.0, gen_spawn_area_size.y / 2.0)
	)
	
	return cluster_parent

# Use 3D noise to decide where to place blocks, creating a natural shape.
func _generate_cloud_shape() -> Array[Transform3D]:
	# Setup noise for this specific cloud
	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.seed = randi()
	_noise.frequency = shape_noise_scale
	_noise.fractal_octaves = shape_noise_octaves
	
	var transforms: Array[Transform3D] = []
	var offset = shape_cluster_dimensions / 2.0
	
	for y in range(shape_cluster_dimensions.y):
		for z in range(shape_cluster_dimensions.z):
			for x in range(shape_cluster_dimensions.x):
				# Get a noise value between -1 and 1
				var noise_val = _noise.get_noise_3d(x, y * 2.0, z) # Stretch Y for flatter clouds
				
				# Remap noise to 0-1 and check against density
				if (noise_val + 1.0) / 2.0 > (1.0 - shape_density):
					var pos = Vector3(x, y, z)
					# Center the cloud around its origin
					pos -= Vector3(offset.x, offset.y / 2.0, offset.z) 
					pos *= shape_cloud_block_size
					transforms.append(Transform3D(Basis(), pos))
					
	return transforms

#
#  Animation and Movement
#

func _move_clouds(delta: float) -> void:
	var half_area = gen_spawn_area_size / 2.0
	
	for cloud in _cloud_clusters:
		if not is_instance_valid(cloud): continue # Safety check
		
		cloud.global_position += anim_cloud_speed * delta
		
		# Seamless Wrapping Logic
		# This makes the clouds appear to be infinite.
		var pos = cloud.global_position
		
		if pos.x > half_area.x:
			pos.x = -half_area.x
		elif pos.x < -half_area.x:
			pos.x = half_area.x
			
		if pos.z > half_area.y:
			pos.z = -half_area.y
		elif pos.z < -half_area.y:
			pos.z = half_area.y
			
		cloud.global_position = pos
