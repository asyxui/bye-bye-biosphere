extends RefCounted
class_name VoxelMaterialCatalog

const MATERIALS: Array[VoxelMaterialDefinition] = [
	preload("res://Resources/Terrain/Stone.tres"),
	preload("res://Resources/Terrain/Iron.tres"),
	preload("res://Resources/Terrain/Dirt.tres"),
	preload("res://Resources/Terrain/Grass.tres"),
	preload("res://Resources/Terrain/Sand.tres"),
	preload("res://Resources/Terrain/Snow.tres"),
	preload("res://Resources/Terrain/Gravel.tres"),
	preload("res://Resources/Terrain/Water.tres"),
]

static func get_definition(voxel_type: int) -> VoxelMaterialDefinition:
	for definition in MATERIALS:
		if definition.voxel_type == voxel_type:
			return definition
	return null
