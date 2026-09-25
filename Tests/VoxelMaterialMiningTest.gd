extends "res://Tests/TestCase.gd"

const EXPECTED_DROPS := {
	1: "8",
	2: "6",
	3: "4",
	4: "13",
	5: "14",
	7: "8",
}

func _run() -> void:
	for voxel_type in EXPECTED_DROPS:
		var material := VoxelMaterialCatalog.get_definition(voxel_type)
		check(material != null)
		var mined_item := material.get_mined_item()
		check(mined_item != null)
		check(mined_item.id == EXPECTED_DROPS[voxel_type])
