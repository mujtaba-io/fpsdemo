extends Node3D

# Set this to be slightly longer than the longest particle lifetime.
# The "ArcingDroplets" last for 2.0 seconds.
@export var lifetime = 2.5

func _ready():
	# Trigger all child particle emitters that are set to 'one_shot'.
	for child in get_children():
		if child is GPUParticles3D:
			child.emitting = true

	# Set a timer to safely delete the scene after the effect is done.
	var timer = Timer.new()
	timer.wait_time = lifetime
	timer.one_shot = true
	timer.timeout.connect(queue_free)
	add_child(timer)
	timer.start()
