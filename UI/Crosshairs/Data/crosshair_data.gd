# CrosshairData.gd
class_name CrosshairData
extends Resource

## This resource holds all the configurable settings for a DynamicCrosshair.
## Create this resource inside your WeaponData resource in the inspector.

@export_group("General Appearance")
## The style of the crosshair.
@export var crosshair_type: CrosshairDrawer.CrosshairType = CrosshairDrawer.CrosshairType.PLUS

## The base color of the crosshair.
@export var color: Color = Color.GOLDENROD

## The thickness of the lines or circles drawn.
@export var line_thickness: float = 0.4

@export_group("Sizing & Dynamics")
## The initial size (length of lines, or radius of circle) at zero recoil.
@export var base_size: int = 20

## How much the crosshair should expand at maximum recoil (1.0).
@export var max_recoil_multiplier: float = 5.0

@export_group("Preset-Specific Settings")
## [PLUS] The gap between the center and the start of the plus-shaped lines.
@export var plus_gap: int = 5

## [CROSS] The gap between the center and the start of the cross-shaped lines.
@export var cross_gap: int = 4

## [CIRCLE] The number of segments (arcs) to draw for the circle.
@export var circle_segments: int = 16

## [CIRCLE] The length of each arc as a percentage of the space available for it.
@export_range(0.0, 1.0, 0.01) var circle_segment_length_percent: float = 0.4

## [CIRCLE] The radius of the central dot. Set to 0 to disable.
@export var circle_dot_size: float = 1.0
