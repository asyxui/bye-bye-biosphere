extends StaticBody3D

var machine_type := "sink"
var structure_id: String = ""
var consumed_count := 0
var input_buffer: ItemBuffer = ItemBuffer.new(4, 64)
var output_buffer: ItemBuffer = ItemBuffer.new(1, 64)

func _ready() -> void:
	add_to_group("machines")
	add_to_group("structures")
	$Intake.body_entered.connect(_on_intake_body_entered)
	_update_label()

func get_input_buffer() -> ItemBuffer:
	return input_buffer

func get_output_buffer() -> ItemBuffer:
	return output_buffer

func _on_intake_body_entered(body: Node3D) -> void:
	if not body is RigidBody3D:
		return
	var drop = body.get_parent()
	if drop == null or drop.get("dropData") == null or drop.get_meta("sink_consumed", false):
		return
	drop.set_meta("sink_consumed", true)
	consumed_count += 1
	_update_label()
	drop.queue_free()

func _update_label() -> void:
	$DeliveredLabel.text = "Delivered: %d" % consumed_count

func get_machine_state() -> Dictionary:
	return {"consumed_count": consumed_count}

func load_machine_state(state: Dictionary) -> void:
	consumed_count = state.get("consumed_count", 0)
	_update_label()
