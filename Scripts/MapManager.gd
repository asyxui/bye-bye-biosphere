extends VoxelLodTerrain

var voxelTool = null

func _ready():
	CustomLogger.log_info("Initializing MapManager")
	var terrainNode = get_tree().root.find_child("Terrain", true, false)
	voxelTool = terrainNode.get_voxel_tool()

func _destroy(origin: Vector3, direction: Vector3):
	var hit = voxelTool.raycast(origin, direction, 100)
	if (hit != null):
		CustomLogger.log_info("raycast hit a block")
		voxelTool.channel = VoxelBuffer.CHANNEL_TYPE
		voxelTool.value = 0
		voxelTool.do_sphere(hit.position, 5)
