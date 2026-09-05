extends Node

const TEST_SCRIPTS := [
	"res://Tests/BiosphereStateTest.gd",
	"res://Tests/ConveyorSimulationTest.gd",
	"res://Tests/HandcraftingTest.gd",
	"res://Tests/ItemTransferTest.gd",
	"res://Tests/ManualSmelterTest.gd",
	"res://Tests/PersistenceStateTest.gd",
	"res://Tests/PlaceableItemTest.gd",
	"res://Tests/PlacementReceiptTest.gd",
	"res://Tests/ResourceConsistencyTest.gd",
	"res://Tests/SaveSchemaTest.gd",
	"res://Tests/SmelterSimulationTest.gd",
	"res://Tests/VoxelMaterialMiningTest.gd",
]

func _ready() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	var failed := false
	for script_path in TEST_SCRIPTS:
		var test_script := load(script_path)
		if test_script == null:
			push_error("Could not load test script: %s" % script_path)
			failed = true
			continue
		var test_case = test_script.new()
		if not test_case.has_method("run"):
			push_error("Invalid test case: %s" % script_path)
			failed = true
			continue
		print("Running %s" % script_path)
		test_case.run(get_tree())
		if bool(test_case.get("failed")):
			failed = true
		await get_tree().process_frame
	get_tree().quit(1 if failed else 0)
