# base_objective.gd
class_name BaseObjective
extends Resource

signal objective_completed
signal objective_updated(progress: float)

@export var objective_name: String = "New Objective"
@export var objective_description: String = "Complete this objective"
@export var is_optional: bool = false
@export var show_progress: bool = false

var is_completed: bool = false
var progress: float = 0.0

# Called by ObjectiveManager when this objective becomes active
func initialize(objective_manager: ObjectiveManager) -> void:
	pass

# Called by ObjectiveManager when this objective is no longer active
func cleanup() -> void:
	pass

func update_progress(new_progress: float) -> void:
	progress = clamp(new_progress, 0.0, 1.0)
	objective_updated.emit(progress)
	
	if progress >= 1.0:
		complete()

func complete() -> void:
	if is_completed:
		print("Objective already completed: ", objective_name)
		return
		
	is_completed = true
	print("\nOBJECTIVE COMPLETED: ", objective_name)
	print("Description: ", objective_description)
	
	if is_optional:
		print("Type: OPTIONAL - Bonus objective completed!")
	else:
		print("Type: REQUIRED - Mandatory objective completed!")
	
	objective_completed.emit()
