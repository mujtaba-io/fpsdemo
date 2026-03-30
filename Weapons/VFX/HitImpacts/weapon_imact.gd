# weapon_impact.gd
class_name WeaponImpact
extends Resource

## The particle/sound scene to spawn on impact.
@export var impact_scene: PackedScene

## The group the hit object must belong to.
## If left empty, this is treated as the "default" impact.
@export var group_name: String = ""
