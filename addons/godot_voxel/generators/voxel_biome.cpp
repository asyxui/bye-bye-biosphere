#include "voxel_biome.h"

void VoxelBiome::_bind_methods()
{
	ClassDB::bind_method(
		D_METHOD("set_base_height", "value"),
		&VoxelBiome::set_base_height
	);

	ClassDB::bind_method(
		D_METHOD("get_base_height"),
		&VoxelBiome::get_base_height
	);

	ClassDB::bind_method(
		D_METHOD("set_terrain_amplitude", "value"),
		&VoxelBiome::set_terrain_amplitude
	);

	ClassDB::bind_method(
		D_METHOD("get_terrain_amplitude"),
		&VoxelBiome::get_terrain_amplitude
	);

	ClassDB::bind_method(
		D_METHOD("set_threshold_center", "value"),
		&VoxelBiome::set_threshold_center
	);

	ClassDB::bind_method(
		D_METHOD("get_threshold_center"),
		&VoxelBiome::get_threshold_center
	);

    ClassDB::bind_method(
	D_METHOD("set_biome_name", "value"),
	&VoxelBiome::set_biome_name
    );

    ClassDB::bind_method(
        D_METHOD("get_biome_name"),
        &VoxelBiome::get_biome_name
    );

    ADD_PROPERTY(
        PropertyInfo(Variant::STRING, "biome_name"),
        "set_biome_name",
        "get_biome_name"
    );

	ADD_PROPERTY(
		PropertyInfo(Variant::FLOAT, "base_height"),
		"set_base_height",
		"get_base_height"
	);

	ADD_PROPERTY(
		PropertyInfo(Variant::FLOAT, "terrain_amplitude"),
		"set_terrain_amplitude",
		"get_terrain_amplitude"
	);

	ADD_PROPERTY(
		PropertyInfo(Variant::FLOAT, "threshold_center"),
		"set_threshold_center",
		"get_threshold_center"
	);
}

void VoxelBiome::set_biome_name(String value)
{
	biome_name = value;
}

String VoxelBiome::get_biome_name() const
{
	return biome_name;
}

void VoxelBiome::set_base_height(float value)
{
	base_height = value;
}

float VoxelBiome::get_base_height() const
{
	return base_height;
}

void VoxelBiome::set_terrain_amplitude(float value)
{
	terrain_amplitude = value;
}

float VoxelBiome::get_terrain_amplitude() const
{
	return terrain_amplitude;
}

void VoxelBiome::set_threshold_center(float value)
{
	threshold_center = value;
}

float VoxelBiome::get_threshold_center() const
{
	return threshold_center;
}