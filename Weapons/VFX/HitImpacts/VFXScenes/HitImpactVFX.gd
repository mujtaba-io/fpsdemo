extends Node3D

# Set this to be slightly longer than the longest particle lifetime.
# The "HeavyDebris" and "LingeringSmoke" last about 2 seconds.
@export var lifetime = 2.5

func _ready():
	# THIS IS THE NEW, CRITICAL PART
	# Find all child nodes that are particle emitters and turn them on.
	# This triggers their 'one_shot' behavior.
	for child in get_children():
		if child is GPUParticles3D:
			child.emitting = true
	#

	# This is the old auto-destroy logic, which is still needed.
	var timer = Timer.new()
	timer.wait_time = lifetime
	timer.one_shot = true
	timer.timeout.connect(queue_free)
	add_child(timer)
	timer.start()
