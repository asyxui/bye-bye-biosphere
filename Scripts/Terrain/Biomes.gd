class_name Biomes
extends Resource

const Plains = "plains"
const Desert = "desert"
const Mountains = "mountains"

static var biomes: Dictionary = {
	Plains: {
		"height_scale": 15,
		"threshold_center": 0.5
	},
	Desert: {
		"height_scale": 4,
		"threshold_center": 0.1
	},
	Mountains: {
		"height_scale": 200,
		"threshold_center": 0.9
	}
}

static func get_property(biome: String, property_name: String):
	if biomes.has(biome) and biomes[biome].has(property_name):
		return biomes[biome][property_name]
	return null
