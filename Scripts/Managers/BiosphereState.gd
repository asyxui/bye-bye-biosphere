## Persisted global progression state for the biosphere and first objective.
class_name BiosphereState
extends Resource

@export var biosphere_integrity: float = 100.0
@export var total_raw_material_extracted: int = 0
@export var total_processed_material: int = 0
@export var objective_delivery_progress: int = 0
@export var objective_completed: bool = false
@export var triggered_event_ids: Array[String] = []

func reset(initial_integrity: float) -> void:
	biosphere_integrity = initial_integrity
	total_raw_material_extracted = 0
	total_processed_material = 0
	objective_delivery_progress = 0
	objective_completed = false
	triggered_event_ids.clear()
