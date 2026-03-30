# CrosshairDrawer.gd
@tool
class_name CrosshairDrawer
extends Control

## An enumeration to define the different crosshair styles.
enum CrosshairType { PLUS, CIRCLE, CROSS }

# EXPORTED VARIABLES (Inspector Settings)

@export_group("Crosshair State")
## The core value (0.0 to 1.0) that drives the crosshair's size.
## Animate or set this value from your weapon script.
@export_range(0.0, 1.0, 0.01) var recoil: float = 0.0:
	set(value):
		recoil = clampf(value, 0.0, 1.0)
		queue_redraw()

@export_group("General Appearance")
## The style of the crosshair. Change this in the Inspector.
@export var crosshair_type: CrosshairType = CrosshairType.PLUS:
	set(value):
		crosshair_type = value
		queue_redraw()

## The base color of the crosshair.
@export var color: Color = Color.GOLDENROD:
	set(value):
		color = value
		queue_redraw()

## The thickness of the lines or circles drawn.
@export var line_thickness: float = 0.4:
	set(value):
		line_thickness = value
		queue_redraw()

@export_group("Sizing & Dynamics")
## The initial size (length of lines, or radius of circle) at zero recoil.
@export var base_size: int = 20:
	set(value):
		base_size = value
		queue_redraw()

## How much the crosshair should expand at maximum recoil (1.0).
## A value of 5.0 means it will expand by 5 times its base_size.
@export var max_recoil_multiplier: float = 5.0:
	set(value):
		max_recoil_multiplier = value
		queue_redraw()

@export_group("Preset-Specific Settings")
## [PLUS] The gap between the center and the start of the plus-shaped lines.
@export var plus_gap: int = 5:
	set(value):
		plus_gap = value
		queue_redraw()

## [CROSS] The gap between the center and the start of the cross-shaped lines.
@export var cross_gap: int = 4:
	set(value):
		cross_gap = value
		queue_redraw()

## [CIRCLE] The number of segments (arcs) to draw for the circle.
@export var circle_segments: int = 16:
	set(value):
		circle_segments = value
		queue_redraw()

## [CIRCLE] The length of each arc as a percentage of the space available for it.
## 0.5 means the arc and the gap are the same size. 1.0 means it's a solid circle.
@export_range(0.0, 1.0, 0.01) var circle_segment_length_percent: float = 0.4:
	set(value):
		circle_segment_length_percent = value
		queue_redraw()

## [CIRCLE] The radius of the central dot. Set to 0 to disable.
@export var circle_dot_size: float = 1.0:
	set(value):
		circle_dot_size = value
		queue_redraw()


# NEW PUBLIC FUNCTION
# This is the only part you need to add to your existing script.
#
## Applies a CrosshairData resource to this node, updating its appearance.
func apply_data(data: CrosshairData) -> void:
	if not data:
		# Hide the crosshair or set to a default if no data is provided.
		visible = false
		return

	# Make sure it's visible if we have data.
	visible = true

	# Copy all properties from the data resource to this node.
	# This will trigger the 'set' functions above and queue a redraw.
	self.crosshair_type = data.crosshair_type
	self.color = data.color
	self.line_thickness = data.line_thickness
	self.base_size = data.base_size
	self.max_recoil_multiplier = data.max_recoil_multiplier
	self.plus_gap = data.plus_gap
	self.cross_gap = data.cross_gap
	self.circle_segments = data.circle_segments
	self.circle_segment_length_percent = data.circle_segment_length_percent
	self.circle_dot_size = data.circle_dot_size


# GODOT CALLBACKS

func _ready() -> void:
	add_to_group("crosshairs")
	queue_redraw()

func _draw() -> void:
	var center: Vector2 = size / 2.0
	var spread: float = lerp(0.0, float(base_size * max_recoil_multiplier), recoil)

	match crosshair_type:
		CrosshairType.PLUS:
			draw_plus_crosshair(center, spread)
		CrosshairType.CIRCLE:
			draw_circle_crosshair(center, spread)
		CrosshairType.CROSS:
			draw_cross_crosshair(center, spread)

# DRAWING LOGIC

func draw_plus_crosshair(center: Vector2, spread: float) -> void:
	var current_gap = plus_gap + spread
	
	# Top line
	draw_line(center + Vector2(0, -current_gap), center + Vector2(0, -current_gap - base_size), color, line_thickness, true)
	# Bottom line
	draw_line(center + Vector2(0, current_gap), center + Vector2(0, current_gap + base_size), color, line_thickness, true)
	# Left line
	draw_line(center + Vector2(-current_gap, 0), center + Vector2(-current_gap - base_size, 0), color, line_thickness, true)
	# Right line
	draw_line(center + Vector2(current_gap, 0), center + Vector2(current_gap + base_size, 0), color, line_thickness, true)

func draw_circle_crosshair(center: Vector2, spread: float) -> void:
	# Draw the central dot if its size is greater than zero.
	if circle_dot_size > 0:
		draw_circle(center, circle_dot_size, color)
		
	var radius = base_size + spread
	
	if circle_segments > 0:
		var angle_step = TAU / circle_segments
		var arc_angle = angle_step * circle_segment_length_percent
		
		for i in range(circle_segments):
			var start_angle = i * angle_step
			var end_angle = start_angle + arc_angle
			draw_arc(center, radius, start_angle, end_angle, 32, color, line_thickness, true)

func draw_cross_crosshair(center: Vector2, spread: float) -> void:
	var current_gap = cross_gap + spread
	
	var directions = [
		Vector2(1, 1).normalized(),
		Vector2(1, -1).normalized(),
		Vector2(-1, -1).normalized(),
		Vector2(-1, 1).normalized()
	]
	
	for dir in directions:
		var start_point = center + dir * current_gap
		var end_point = center + dir * (current_gap + base_size)
		draw_line(start_point, end_point, color, line_thickness, true)


# Crosshair resets itself
func _process(delta):
	recoil -= delta
