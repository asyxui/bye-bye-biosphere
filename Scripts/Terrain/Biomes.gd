class_name Biomes
extends Resource

const Plains = "plains"
const Desert = "desert"
const Mountains = "mountains"

static var biomes: Dictionary = {
	Plains: {
		"base_height": 20,
		"terrain_amplitude": 15,
		"threshold_center": 0.5
	},
	Desert: {
		"base_height": 10,
		"terrain_amplitude": 4,
		"threshold_center": 0.1
	},
	Mountains: {
		"base_height": 250,
		"terrain_amplitude": 150,
		"threshold_center": 0.9
	}
}

static func get_property(biome: String, property_name: String):
	if biomes.has(biome) and biomes[biome].has(property_name):
		return biomes[biome][property_name]
	return null
