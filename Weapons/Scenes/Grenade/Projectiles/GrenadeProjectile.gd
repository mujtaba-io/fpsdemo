# grenade_projectile.gd
extends RigidBody3D

@export var explosion_vfx_scene: PackedScene # < ADD THIS LINE

# These variables will be set by the weapon that fires the grenade.
var damage: int = 100
var shooter_body: Node3D = null # To avoid self-damage

@export var fuse_timer: Timer
@export var explosion_area: Area3D

var has_exploded: bool = false

func _ready() -> void:
	fuse_timer.timeout.connect(explode)
	fuse_timer.start()
	self.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body == shooter_body:
		return
	explode()

func explode() -> void:
	if has_exploded:
		return
	has_exploded = true
	
	print("GRENADE: BOOM!")
	
	# SPAWN VISUALS
	# Check if the VFX scene has been assigned in the editor.
	if explosion_vfx_scene:
		# Create an instance of the VFX.
		var vfx_instance = explosion_vfx_scene.instantiate()
		# Add it to the main scene tree, not as a child of the grenade.
		get_tree().get_root().add_child(vfx_instance)
		# Position it exactly where the grenade was.
		vfx_instance.global_position = self.global_position

	
	# Find all bodies within the explosion radius.
	var bodies_in_radius = explosion_area.get_overlapping_bodies()
	for body in bodies_in_radius:
		if body == shooter_body:
			continue
		if body.has_method("take_damage"):
			body.take_damage(damage)
			print("Grenade dealt %d damage to %s" % [damage, body.name])
			
	queue_free()
