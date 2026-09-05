extends RefCounted
class_name VoxelMaterialCatalog

const MATERIALS: Array[VoxelMaterialDefinition] = [
	preload("res://Resources/Terrain/Stone.tres"),
	preload("res://Resources/Terrain/Iron.tres"),
]

static func get_definition(voxel_type: int) -> VoxelMaterialDefinition:
	for definition in MATERIALS:
		if definition.voxel_type == voxel_type:
			return definition
	return null
