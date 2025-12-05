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
		# before we destroy the world we need to query the blocks to find out what was there
		voxelTool.channel = VoxelBuffer.CHANNEL_TYPE
		voxelTool.value = 0
		
		# store the drops temporarily, so we can drop the items after removing the terrain
		var drops: Array[int] = []
		var coordsWithDrops: Array[Vector3] = []
		var coords = sphere_coords(hit.position, 2)
		
		for coord in coords: 
			var type: int = voxelTool.get_voxel(coord)
			if (type != 0):	
				drops.append(type)
				coordsWithDrops.append(coord)
				
		voxelTool.do_sphere(hit.position, 2)
		
		await get_tree().create_timer(0.2).timeout 
		
		for i in range(coordsWithDrops.size()): 
			var coord: Vector3 = coordsWithDrops[i]
			coord.y += 1
			drop_item(drops[i], coord)

func save_map():
	voxelTerrain.save_modified_blocks()

# create a blocky sphere by radius
func sphere_coords(center: Vector3, radius: int) -> Array[Vector3]:
	var coords: Array[Vector3] = []
	for x in range(-radius, radius):
		for y in range(-radius, radius):
			for z in range(-radius, radius):
				var pos = Vector3(x, y, z)
				if (pos.length() <= radius):
					coords.append(pos + center)
	return coords
	
	
func drop_item(type: int, coords: Vector3):
	var newDrop: Node3D;
	match type:
		1:
			newDrop = preload("res://Assets/Items/Rock.tscn").instantiate()
		2: 
			newDrop = preload("res://Assets/Items/PurpleOre.tscn").instantiate()
	newDrop.global_position = coords
	voxelTerrain.add_child(newDrop)
	
