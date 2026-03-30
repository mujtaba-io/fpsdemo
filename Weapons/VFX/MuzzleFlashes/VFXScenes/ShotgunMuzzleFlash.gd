extends Node3D

# An array to hold references to all the particle systems in this scene.
var particle_emitters: Array[GPUParticles3D]


func _ready():
	# When the scene is ready, find all children that are GPUParticles3D
	# and store them in our array for quick access later.
	for child in get_children():
		if child is GPUParticles3D:
			particle_emitters.append(child)


# PUBLIC API
# Call this function from your gun script every time you want to fire.
func start():
	"""
	Triggers a single, powerful muzzle flash burst.
	All particle systems are set to 'one_shot', so they will fire once
	and automatically reset, ready for the next call.
	"""
	if particle_emitters.is_empty():
		return

	for emitter in particle_emitters:
		emitter.emitting = true
