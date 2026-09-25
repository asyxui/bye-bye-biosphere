class_name QuestDefinition
extends Resource

@export var quest_id: StringName = &""
@export var title: String = ""
@export var sort_order: int = 0
@export var steps: Array[QuestStepDefinition] = []
