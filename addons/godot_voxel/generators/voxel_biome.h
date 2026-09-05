#pragma once

#include <string.h>
#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/core/class_db.hpp>

using namespace godot;

class VoxelBiome : public Resource {
	GDCLASS(VoxelBiome, Resource)

private:
	String biome_name = "Unnamed";
	float base_height = 0.0f;
	float terrain_amplitude = 0.0f;
	float threshold_center = 0.0f;
	int surface_voxel_type = 0;
	float soil_depth_min = 3.0f;
	float soil_depth_max = 3.0f;
	bool is_ocean = false;
	float water_level = 12.0f;

protected:
	static void _bind_methods();

public:
	// Values for the surface_voxel_type property (kept in sync with the PROPERTY_HINT_ENUM string in _bind_methods).
	enum SurfaceType {
		SURFACE_GRASS = 0,
		SURFACE_SAND = 1,
		SURFACE_ROCK = 2,
	};

	String get_biome_name() const;
	void set_biome_name(String value);

	void set_base_height(float value);
	float get_base_height() const;

	void set_terrain_amplitude(float value);
	float get_terrain_amplitude() const;

	void set_threshold_center(float value);
	float get_threshold_center() const;

	void set_surface_voxel_type(int value);
	int get_surface_voxel_type() const;

	void set_soil_depth_min(float value);
	float get_soil_depth_min() const;

	void set_soil_depth_max(float value);
	float get_soil_depth_max() const;

	void set_is_ocean(bool value);
	bool get_is_ocean() const;

	void set_water_level(float value);
	float get_water_level() const;
};
