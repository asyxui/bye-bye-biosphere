extends VoxelLodTerrain

var voxelTool: VoxelTool = null
var voxelTerrain: VoxelLodTerrain = null

func _ready():
	CustomLogger.log_info("Initializing MapManager")
	voxelTerrain = get_tree().root.find_child("Terrain", true, false)
	voxelTool = voxelTerrain.get_voxel_tool()

func _destroy(origin: Vector3, direction: Vector3):
	var hit = voxelTool.raycast(origin, direction, 100)
	if (hit != null):
		CustomLogger.log_info("raycast hit a block")
		voxelTool.channel = VoxelBuffer.CHANNEL_TYPE
		voxelTool.value = 0
		voxelTool.do_sphere(hit.position, 5)

func save_map():
	voxelTerrain.save_modified_blocks()
