extends StaticBody3D

const EMIT_INTERVAL: float = 1.0
const IRON_ORE := preload("res://Resources/Items/IronOre.tres")

var machine_type: String = "producer"
var structure_id: String = ""
## The producer now creates logical output. A conveyor pulls from this buffer
## on the fixed simulation tick, no rigid-body pickup is involved.
var input_buffer: ItemBuffer = ItemBuffer.new(1, 64)
var output_buffer: ItemBuffer = ItemBuffer.new(4, 64)
var _production_accumulator: float = 0.0

func _ready() -> void:
	add_to_group("machines")
	add_to_group("structures")

func get_input_buffer() -> ItemBuffer:
	return input_buffer

func get_output_buffer() -> ItemBuffer:
	return output_buffer

func _physics_process(delta: float) -> void:
	_production_accumulator += maxf(0.0, delta)
	while _production_accumulator >= EMIT_INTERVAL:
		_production_accumulator -= EMIT_INTERVAL
		var produced: ItemStack = ItemStack.new(IRON_ORE, 1)
		if output_buffer.get_insertable_quantity(produced, 1) > 0:
			output_buffer.insert_stack(produced, 1)

func get_machine_state() -> Dictionary:
	return {
		"input_buffer": input_buffer.to_dict(),
		"output_buffer": output_buffer.to_dict(),
		"production_accumulator": _production_accumulator
	}

func load_machine_state(state: Dictionary) -> void:
	input_buffer.load_dict(state.get("input_buffer", []))
	output_buffer.load_dict(state.get("output_buffer", []))
	_production_accumulator = maxf(0.0, float(state.get("production_accumulator", 0.0)))
