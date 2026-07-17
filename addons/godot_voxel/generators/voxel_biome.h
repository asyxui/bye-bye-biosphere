#pragma once

#include <string.h>
#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/core/class_db.hpp>

using namespace godot;


class VoxelBiome : public Resource
{
	GDCLASS(VoxelBiome, Resource)

private:

	String biome_name = "Unnamed";
	float base_height = 0.0f;
	float terrain_amplitude = 0.0f;
	float threshold_center = 0.0f;


protected:

	static void _bind_methods();


public:

	String get_biome_name() const;
	void set_biome_name(String value);

	void set_base_height(float value);
	float get_base_height() const;

	void set_terrain_amplitude(float value);
	float get_terrain_amplitude() const;

	void set_threshold_center(float value);
	float get_threshold_center() const;
};