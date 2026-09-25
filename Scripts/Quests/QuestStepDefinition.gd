class_name QuestStepDefinition
extends Resource

@export var step_id: StringName = &""
@export var title: String = ""
@export_multiline var description: String = ""
@export var optional: bool = false
@export var objectives: Array[QuestObjectiveDefinition] = []
