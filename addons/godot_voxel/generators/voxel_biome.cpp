#include "voxel_biome.h"

void VoxelBiome::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_base_height", "value"), &VoxelBiome::set_base_height);

	ClassDB::bind_method(D_METHOD("get_base_height"), &VoxelBiome::get_base_height);

	ClassDB::bind_method(D_METHOD("set_terrain_amplitude", "value"), &VoxelBiome::set_terrain_amplitude);

	ClassDB::bind_method(D_METHOD("get_terrain_amplitude"), &VoxelBiome::get_terrain_amplitude);

	ClassDB::bind_method(D_METHOD("set_threshold_center", "value"), &VoxelBiome::set_threshold_center);

	ClassDB::bind_method(D_METHOD("get_threshold_center"), &VoxelBiome::get_threshold_center);

	ClassDB::bind_method(D_METHOD("set_biome_name", "value"), &VoxelBiome::set_biome_name);

	ClassDB::bind_method(D_METHOD("get_biome_name"), &VoxelBiome::get_biome_name);

	ClassDB::bind_method(D_METHOD("set_surface_voxel_type", "value"), &VoxelBiome::set_surface_voxel_type);

	ClassDB::bind_method(D_METHOD("get_surface_voxel_type"), &VoxelBiome::get_surface_voxel_type);

	ClassDB::bind_method(D_METHOD("set_soil_depth_min", "value"), &VoxelBiome::set_soil_depth_min);

	ClassDB::bind_method(D_METHOD("get_soil_depth_min"), &VoxelBiome::get_soil_depth_min);

	ClassDB::bind_method(D_METHOD("set_soil_depth_max", "value"), &VoxelBiome::set_soil_depth_max);

	ClassDB::bind_method(D_METHOD("get_soil_depth_max"), &VoxelBiome::get_soil_depth_max);

	ClassDB::bind_method(D_METHOD("set_is_ocean", "value"), &VoxelBiome::set_is_ocean);

	ClassDB::bind_method(D_METHOD("get_is_ocean"), &VoxelBiome::get_is_ocean);

	ClassDB::bind_method(D_METHOD("set_water_level", "value"), &VoxelBiome::set_water_level);

	ClassDB::bind_method(D_METHOD("get_water_level"), &VoxelBiome::get_water_level);

	ADD_PROPERTY(PropertyInfo(Variant::STRING, "biome_name"), "set_biome_name", "get_biome_name");

	ADD_PROPERTY(PropertyInfo(Variant::INT, "surface_voxel_type", PROPERTY_HINT_ENUM, "Grass,Sand,Rock"),
				 "set_surface_voxel_type",
				 "get_surface_voxel_type");

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "soil_depth_min", PROPERTY_HINT_RANGE, "0,50,1"),
				 "set_soil_depth_min",
				 "get_soil_depth_min");

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "soil_depth_max", PROPERTY_HINT_RANGE, "0,50,1"),
				 "set_soil_depth_max",
				 "get_soil_depth_max");

	ADD_PROPERTY(PropertyInfo(Variant::BOOL, "is_ocean"), "set_is_ocean", "get_is_ocean");

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "water_level"), "set_water_level", "get_water_level");

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "base_height"), "set_base_height", "get_base_height");

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "terrain_amplitude"), "set_terrain_amplitude", "get_terrain_amplitude");

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "threshold_center"), "set_threshold_center", "get_threshold_center");
}

void VoxelBiome::set_biome_name(String value) {
	biome_name = value;
}

String VoxelBiome::get_biome_name() const {
	return biome_name;
}

void VoxelBiome::set_base_height(float value) {
	base_height = value;
}

float VoxelBiome::get_base_height() const {
	return base_height;
}

void VoxelBiome::set_terrain_amplitude(float value) {
	terrain_amplitude = value;
}

float VoxelBiome::get_terrain_amplitude() const {
	return terrain_amplitude;
}

void VoxelBiome::set_threshold_center(float value) {
	threshold_center = value;
}

float VoxelBiome::get_threshold_center() const {
	return threshold_center;
}

void VoxelBiome::set_surface_voxel_type(int value) {
	surface_voxel_type = value;
}

int VoxelBiome::get_surface_voxel_type() const {
	return surface_voxel_type;
}

void VoxelBiome::set_soil_depth_min(float value) {
	soil_depth_min = value;
}

float VoxelBiome::get_soil_depth_min() const {
	return soil_depth_min;
}

void VoxelBiome::set_soil_depth_max(float value) {
	soil_depth_max = value;
}

float VoxelBiome::get_soil_depth_max() const {
	return soil_depth_max;
}

void VoxelBiome::set_is_ocean(bool value) {
	is_ocean = value;
}

bool VoxelBiome::get_is_ocean() const {
	return is_ocean;
}

void VoxelBiome::set_water_level(float value) {
	water_level = value;
}

float VoxelBiome::get_water_level() const {
	return water_level;
}
