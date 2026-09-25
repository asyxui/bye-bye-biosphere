## Data-driven balance and event configuration for the first biosphere loop.
class_name BiosphereConfig
extends Resource

@export var initial_integrity: float = 100.0
@export var mining_integrity_loss: float = 0.01
@export var objective_item_id: String = "5"
@export var objective_delivery_target: int = 10
@export var air_quality_event_threshold: float = 75.0
@export var air_quality_event_id: String = "air_quality_warning"
@export var air_quality_event_title: String = "AIR QUALITY WARNING"
@export_multiline var air_quality_event_description: String = "Industrial activity has pushed the local atmosphere past a critical threshold. The biosphere is ANGERY."
