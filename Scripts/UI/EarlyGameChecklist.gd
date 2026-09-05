extends PanelContainer

const STONE_ID := "8"
const IRON_ORE_ID := "6"
const REQUIRED_RAW_MATERIALS := 13
const REQUIRED_PROCESSED_INGOTS := 7

@onready var _label: Label = $MarginContainer/Label
var _refresh_timer: float = 0.0

func _ready() -> void:
	BiosphereManager.state_changed.connect(_refresh)
	_refresh(BiosphereManager.state)

func _process(delta: float) -> void:
	_refresh_timer += delta
	if _refresh_timer < 0.5:
		return
	_refresh_timer = 0.0
	_refresh(BiosphereManager.state)

func _refresh(state: BiosphereState) -> void:
	if _has_automated_line():
		hide()
		return
	show()
	var raw_complete := state.total_raw_material_extracted >= REQUIRED_RAW_MATERIALS
	var manual_complete := _has_machine_type("manual_smelter")
	var ingots_complete := state.total_processed_material >= REQUIRED_PROCESSED_INGOTS
	var line_complete := _has_automated_line()
	var delivered_complete := state.objective_delivery_progress >= BiosphereManager.get_delivery_target()
	_label.text = "BOOTSTRAP CHECKLIST\n%s Mine 12 Stone and Iron Ore\n%s Craft and place a Manual Smelter\n%s Produce 7 Iron Ingots\n%s Craft the factory line\n%s Deliver 10 Iron Ingots" % [
		_marker(raw_complete),
		_marker(manual_complete),
		_marker(ingots_complete),
		_marker(line_complete),
		_marker(delivered_complete)
	]

func _marker(done: bool) -> String:
	return "✓" if done else "□"

func _has_machine_type(machine_type: String) -> bool:
	for machine in MachineManager.machines:
		if is_instance_valid(machine) and str(machine.get("machine_type")) == machine_type:
			return true
	return false

func _has_automated_line() -> bool:
	return _has_machine_type("smelter") and _has_machine_type("sink") and not ConveyorConnectionManager.belts.is_empty()
