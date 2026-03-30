# ObjectivesSystem/ObjectiveManager.gd
class_name ObjectiveManager
extends Node

signal objective_changed(current_objective: BaseObjective)
signal all_objectives_completed

@export_category("Objectives")
@export var objectives: Array[BaseObjective] = []
@export var sequential_mode: bool = true ## If true, objectives must be completed in order. If false, objectives can be completed in any order.

var current_objective_index: int = 0
var current_objective: BaseObjective = null
var completed_objectives: Array[bool] = []

func _ready() -> void:
	print("OBJECTIVE SYSTEM INITIALIZED")
	print("Total objectives loaded: ", objectives.size())
	print("Sequential mode: ", sequential_mode)
	
	# Initialize completed objectives tracking
	completed_objectives.resize(objectives.size())
	for i in range(objectives.size()):
		completed_objectives[i] = false
	
	if objectives.size() > 0:
		for i in range(objectives.size()):
			print("Objective ", i + 1, ": ", objectives[i].objective_name, " - ", objectives[i].objective_description)
			   print("")
		
		if sequential_mode:
			start_objective(0)
		else:
			start_all_objectives()
	else:
		print("WARNING: No objectives found! Please add objectives to the ObjectiveManager.")
			   print("")

func start_objective(index: int) -> void:
	print("\nSTARTING NEW OBJECTIVE")
	
	# Clean up previous objective
	if current_objective:
		print("Cleaning up previous objective: ", current_objective.objective_name)
		current_objective.cleanup()
		current_objective.objective_completed.disconnect(_on_objective_completed)
		current_objective.objective_updated.disconnect(_on_objective_updated)
	
	# Set new objective
	current_objective_index = index
	current_objective = objectives[index]
	
	print("Objective ", index + 1, " of ", objectives.size(), ": ", current_objective.objective_name)
	print("Description: ", current_objective.objective_description)
	if current_objective.is_optional:
		print("Type: OPTIONAL")
	else:
		print("Type: REQUIRED")
	
	# Connect signals
	current_objective.objective_completed.connect(_on_objective_completed)
	current_objective.objective_updated.connect(_on_objective_updated)
	
	# Initialize the objective
	current_objective.initialize(self)
	
	# Notify UI
	objective_changed.emit(current_objective)
	
	print("Objective is now active and ready!")
	print("")

func start_all_objectives() -> void:
	print("\nSTARTING ALL OBJECTIVES (FLEXIBLE MODE)")
	
	for i in range(objectives.size()):
		var objective = objectives[i]
		print("Initializing objective ", i + 1, ": ", objective.objective_name)
		
		# Connect signals for each objective
		objective.objective_completed.connect(_on_objective_completed_flexible.bind(i))
		objective.objective_updated.connect(_on_objective_updated_flexible.bind(i))
		
		# Initialize the objective
		objective.initialize(self)
	
	# Set current objective to first one for UI purposes
	current_objective = objectives[0]
	current_objective_index = 0
	objective_changed.emit(current_objective)
	
	print("All objectives are now active and ready!")
	print("You can complete them in any order!")
	print("")

func _on_objective_completed() -> void:
	print("\nOBJECTIVE COMPLETED!")
	print("Completed: ", current_objective.objective_name)
	
	# Check if all objectives are completed
	if current_objective_index == objectives.size() - 1:
			   print("\nMISSION PASSED")
		print("ALL OBJECTIVES COMPLETED!")
		print("Congratulations, you have finished all tasks!")
			   print("")
		all_objectives_completed.emit()
	else:
		var remaining = objectives.size() - current_objective_index - 1
		print("Objectives remaining: ", remaining)
		print("Moving to next objective...")
			   print("")
		# Start next objective
		start_objective(current_objective_index + 1)

func _on_objective_completed_flexible(objective_index: int) -> void:
	var completed_objective = objectives[objective_index]
	print("\nOBJECTIVE COMPLETED!")
	print("Completed: ", completed_objective.objective_name, " (", objective_index + 1, " of ", objectives.size(), ")")
	
	# Mark as completed
	completed_objectives[objective_index] = true
	
	# Check if all objectives are completed
	var all_completed = true
	var completed_count = 0
	for i in range(objectives.size()):
		if completed_objectives[i]:
			completed_count += 1
		else:
			all_completed = false
	
	print("Progress: ", completed_count, "/", objectives.size(), " objectives completed")
	
	if all_completed:
			   print("\nMISSION PASSED")
		print("ALL OBJECTIVES COMPLETED!")
		print("Congratulations, you have finished all tasks!")
			   print("")
		all_objectives_completed.emit()
	else:
		var remaining = objectives.size() - completed_count
		print("Objectives remaining: ", remaining)
			   print("")
		
		# Update current objective to next incomplete one for UI
		update_current_objective_display()

func _on_objective_updated(progress: float) -> void:
	var percentage = int(progress * 100)
	print("Objective Progress: ", current_objective.objective_name, " - ", percentage, "%")
	
	if percentage >= 75:
		print("Almost there! Keep going!")
	elif percentage >= 50:
		print("Halfway done!")
	elif percentage >= 25:
		print("Good progress!")

func _on_objective_updated_flexible(objective_index: int, progress: float) -> void:
	var objective = objectives[objective_index]
	var percentage = int(progress * 100)
	print("Objective Progress: ", objective.objective_name, " (", objective_index + 1, "/", objectives.size(), ") - ", percentage, "%")
	
	if percentage >= 75:
		print("Almost there! Keep going!")
	elif percentage >= 50:
		print("Halfway done!")
	elif percentage >= 25:
		print("Good progress!")

func update_current_objective_display() -> void:
	# Find the next incomplete objective for UI display
	for i in range(objectives.size()):
		if not completed_objectives[i]:
			current_objective = objectives[i]
			current_objective_index = i
			objective_changed.emit(current_objective)
			return
	
	# If all are completed, this shouldn't happen but just in case
	current_objective = null

# Helper function to get objective by name
func get_objective_by_name(name: String) -> BaseObjective:
	for objective in objectives:
		if objective.objective_name == name:
			return objective
	return null

# Debug function to print current objective status
func debug_print_status() -> void:
	print("\nOBJECTIVE STATUS DEBUG")
	print("Sequential mode: ", sequential_mode)
	print("Current objective index: ", current_objective_index + 1, " of ", objectives.size())
	
	if sequential_mode:
		if current_objective:
			print("Current objective: ", current_objective.objective_name)
			print("Description: ", current_objective.objective_description)
			print("Progress: ", current_objective.progress * 100, "%")
			print("Completed: ", current_objective.is_completed)
			print("Optional: ", current_objective.is_optional)
		else:
			print("No current objective")
	else:
		print("ALL OBJECTIVES STATUS")
		for i in range(objectives.size()):
			var obj = objectives[i]
			   var status = "" if completed_objectives[i] else ""
			print(status, " Objective ", i + 1, ": ", obj.objective_name)
			print("   Progress: ", obj.progress * 100, "%")
			print("   Completed: ", obj.is_completed)
	print("")

# Function to skip current objective (for testing)
func debug_skip_current_objective() -> void:
	if sequential_mode:
		if current_objective and not current_objective.is_completed:
			   print("DEBUG: Skipping current objective: ", current_objective.objective_name)
			current_objective.complete()
		else:
			   print("DEBUG: No active objective to skip")
	else:
		print("DEBUG: In flexible mode, specify which objective to skip using debug_skip_objective(index)")

# Function to skip specific objective by index (for flexible mode)
func debug_skip_objective(index: int) -> void:
	if index >= 0 and index < objectives.size():
		var objective = objectives[index]
		if not completed_objectives[index]:
			   print("DEBUG: Skipping objective ", index + 1, ": ", objective.objective_name)
			objective.complete()
		else:
			   print("DEBUG: Objective ", index + 1, " is already completed")
	else:
		print("DEBUG: Invalid objective index: ", index)
