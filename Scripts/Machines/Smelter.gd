extends StaticBody3D
class_name Smelter

signal ecological_damage_generated(amount: float)

const IRON_SMELTING_RECIPE: Recipe = preload("res://Resources/Recipes/IronSmelting.tres")
const FIXED_SIMULATION_STEP: float = 1.0 / 60.0
const MAX_SIMULATION_STEPS_PER_FRAME: int = 8
const POSITION_EPSILON: float = 0.0001

enum ProcessingState { IDLE, RUNNING, INPUT_STARVED, OUTPUT_BLOCKED }

var machine_type: String = "smelter"
var structure_id: String = ""
var input_buffer: ItemBuffer = ItemBuffer.new(1, 64)
var output_buffer: ItemBuffer = ItemBuffer.new(1, 64)
var active_recipe: Recipe = IRON_SMELTING_RECIPE
var processing_progress: float = 0.0
var processing_state: int = ProcessingState.INPUT_STARVED
var total_ecological_damage: float = 0.0

var _processing_active: bool = false
var _pending_output: ItemStack = null
var _simulation_accumulator: float = 0.0
@onready var _status_label: Label3D = $StatusLabel

func _ready() -> void:
	add_to_group("machines")
	add_to_group("structures")
	_update_status_label()

func get_input_buffer() -> ItemBuffer:
	return input_buffer

func get_output_buffer() -> ItemBuffer:
	return output_buffer

## Inserts one or more recipe inputs from the player's inventory. The caller
## uses the shared ItemTransfer contract, so inventory ownership is removed
## before the smelter buffer receives the item.
func insert_from_inventory(quantity: int = 1) -> int:
	if quantity <= 0 or active_recipe == null:
		return 0
	var inventory: Inventory = InventoryManager.get_inventory()
	if inventory == null:
		return 0

	var moved_total: int = 0
	for requirement_key in active_recipe.get_input_requirements():
		var item_id: String = str(requirement_key)
		if moved_total >= quantity:
			break
		var available: int = mini(quantity - moved_total, inventory.get_extractable_quantity(item_id))
		if available <= 0:
			continue
		moved_total += ItemTransfer.transfer(inventory, input_buffer, item_id, available)

	if moved_total > 0:
		inventory.items_changed.emit()
		_update_status_label()
	return moved_total

func _physics_process(delta: float) -> void:
	_simulation_accumulator += maxf(0.0, delta)
	var steps: int = 0
	while _simulation_accumulator >= FIXED_SIMULATION_STEP and steps < MAX_SIMULATION_STEPS_PER_FRAME:
		_simulation_accumulator -= FIXED_SIMULATION_STEP
		_simulate_step(FIXED_SIMULATION_STEP)
		steps += 1
	if steps >= MAX_SIMULATION_STEPS_PER_FRAME:
		_simulation_accumulator = 0.0

func _simulate_step(delta: float) -> void:
	if active_recipe == null:
		_processing_active = false
		processing_state = ProcessingState.IDLE
		_update_status_label()
		return

	if _pending_output != null or (_processing_active and processing_progress >= active_recipe.processing_duration - POSITION_EPSILON):
		_finish_processing()
		return

	if _processing_active:
		processing_progress = minf(active_recipe.processing_duration, processing_progress + delta)
		processing_state = ProcessingState.RUNNING
		if processing_progress >= active_recipe.processing_duration - POSITION_EPSILON:
			_finish_processing()
		else:
			_update_status_label()
		return

	if not _has_required_inputs():
		processing_state = ProcessingState.INPUT_STARVED
		_update_status_label()
		return

	_begin_processing()

func _has_required_inputs() -> bool:
	var requirements: Dictionary = active_recipe.get_input_requirements()
	for requirement_key in requirements:
		var item_id: String = str(requirement_key)
		var required: int = int(requirements[item_id])
		if input_buffer.get_extractable_quantity(item_id) < required:
			return false
	return true

func _begin_processing() -> void:
	var requirements: Dictionary = active_recipe.get_input_requirements()
	for requirement_key in requirements:
		var item_id: String = str(requirement_key)
		if input_buffer.get_extractable_quantity(item_id) < int(requirements[item_id]):
			processing_state = ProcessingState.INPUT_STARVED
			_update_status_label()
			return

	# Consume the inputs at start. The output is held as a pending logical stack
	# if the output buffer is full when processing completes.
	var consumed_inputs: Array[ItemStack] = []
	for requirement_key in requirements:
		var item_id: String = str(requirement_key)
		var consumed: ItemStack = input_buffer.extract_stack(item_id, int(requirements[item_id]))
		if consumed == null:
			for rollback_stack in consumed_inputs:
				input_buffer.insert_stack(rollback_stack)
			push_error("Smelter input reservation failed for item id: %s" % item_id)
			processing_state = ProcessingState.INPUT_STARVED
			_update_status_label()
			return
		consumed_inputs.append(consumed)

	_processing_active = true
	processing_progress = 0.0
	processing_state = ProcessingState.RUNNING
	_update_status_label()

func _finish_processing() -> void:
	if _pending_output == null:
		var output_item: InventoryItem = ItemUtils.item_object_by_id(active_recipe.output_item_id)
		if output_item == null:
			push_error("Smelter recipe output item not found: %s" % active_recipe.output_item_id)
			processing_state = ProcessingState.OUTPUT_BLOCKED
			_update_status_label()
			return
		_pending_output = ItemStack.new(
			output_item,
			active_recipe.output_quantity
		)
	if _pending_output == null or _pending_output.quantity <= 0:
		push_error("Smelter recipe has no valid output: %s" % active_recipe.id)
		processing_state = ProcessingState.OUTPUT_BLOCKED
		_update_status_label()
		return

	output_buffer.insert_stack(_pending_output)
	if _pending_output.quantity > 0:
		processing_state = ProcessingState.OUTPUT_BLOCKED
		_update_status_label()
		return

	_pending_output = null
	_processing_active = false
	processing_progress = 0.0
	total_ecological_damage += active_recipe.ecological_damage
	ecological_damage_generated.emit(active_recipe.ecological_damage)
	BiosphereManager.record_processed_material(active_recipe.output_quantity, active_recipe.ecological_damage)
	processing_state = ProcessingState.IDLE
	_update_status_label()

func get_processing_state_name() -> String:
	match processing_state:
		ProcessingState.RUNNING:
			return "Running"
		ProcessingState.INPUT_STARVED:
			return "Input-starved"
		ProcessingState.OUTPUT_BLOCKED:
			return "Output-blocked"
		_:
			return "Idle"

func _update_status_label() -> void:
	if not is_instance_valid(_status_label):
		return
	var duration: float = active_recipe.processing_duration if active_recipe != null else 0.0
	var progress_percent: float = 0.0 if duration <= POSITION_EPSILON else clampf(processing_progress / duration, 0.0, 1.0) * 100.0
	_status_label.text = "%s\n%.0f%%\nIn %d  Out %d" % [
		get_processing_state_name(),
		progress_percent,
		input_buffer.get_total_quantity(),
		output_buffer.get_total_quantity()
	]
	_status_label.modulate = Color(0.4, 1.0, 0.5) if processing_state == ProcessingState.RUNNING else Color.WHITE

func get_machine_state() -> Dictionary:
	return {
		"active_recipe_id": active_recipe.id if active_recipe != null else "",
		"processing_progress": processing_progress,
		"processing_active": _processing_active,
		"processing_state": processing_state,
		"total_ecological_damage": total_ecological_damage,
		"input_buffer": _serialize_buffer(input_buffer),
		"output_buffer": _serialize_buffer(output_buffer),
		"pending_output": _serialize_stack(_pending_output)
	}

func load_machine_state(state: Dictionary) -> void:
	active_recipe = _load_recipe_by_id(str(state.get("active_recipe_id", IRON_SMELTING_RECIPE.id)))
	_restore_buffer(input_buffer, state.get("input_buffer", []))
	_restore_buffer(output_buffer, state.get("output_buffer", []))
	processing_progress = clampf(float(state.get("processing_progress", 0.0)), 0.0, active_recipe.processing_duration)
	_processing_active = bool(state.get("processing_active", false))
	processing_state = clampi(int(state.get("processing_state", ProcessingState.INPUT_STARVED)), ProcessingState.IDLE, ProcessingState.OUTPUT_BLOCKED)
	total_ecological_damage = float(state.get("total_ecological_damage", 0.0))
	_pending_output = _deserialize_stack(state.get("pending_output", {}))
	_update_status_label()

func _load_recipe_by_id(recipe_id: String) -> Recipe:
	var recipe_path := "res://Resources/Recipes/%s.tres" % recipe_id
	if ResourceLoader.exists(recipe_path):
		var loaded_recipe = load(recipe_path)
		if loaded_recipe is Recipe:
			return loaded_recipe as Recipe
	return IRON_SMELTING_RECIPE

func _serialize_buffer(buffer: ItemBuffer) -> Array[Dictionary]:
	var data: Array[Dictionary] = []
	for stack_value in buffer.stacks:
		var stack: ItemStack = stack_value as ItemStack
		data.append(_serialize_stack(stack))
	return data

func _serialize_stack(stack: ItemStack) -> Dictionary:
	if stack == null or stack.quantity <= 0:
		return {}
	return {
		"item_id": stack.item_id,
		"quantity": stack.quantity,
		"metadata": stack.metadata
	}

func _deserialize_stack(data: Dictionary) -> ItemStack:
	var item_id: String = str(data.get("item_id", ""))
	var quantity: int = int(data.get("quantity", 0))
	if item_id.is_empty() or quantity <= 0:
		return null
	var metadata: Dictionary = data.get("metadata", {})
	return ItemStack.new(ItemUtils.item_object_by_id(item_id), quantity, metadata)

func _restore_buffer(buffer: ItemBuffer, data: Array) -> void:
	buffer.stacks.clear()
	for stack_value in data:
		if not stack_value is Dictionary:
			continue
		var stack_data: Dictionary = stack_value
		var stack := _deserialize_stack(stack_data)
		if stack != null:
			buffer.insert_stack(stack)
