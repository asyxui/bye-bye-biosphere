#pragma once

#include "generators/voxel_generator.h"
#include "storage/voxel_buffer.h"
#include "voxel_biome.h"

#include "util/noise/fast_noise_lite/fast_noise_lite.h"

#include <godot_cpp/classes/curve.hpp>

using namespace godot;

namespace zylann {
namespace voxel {

class VoxelGeneratorFast : public VoxelGenerator {
	GDCLASS(VoxelGeneratorFast, VoxelGenerator)

private:
	Ref<ZN_FastNoiseLite> block_type_noise;
	Ref<ZN_FastNoiseLite> terrain_noise;
	Ref<ZN_FastNoiseLite> cave_noise;
	Ref<ZN_FastNoiseLite> biome_noise;
	Ref<ZN_FastNoiseLite> soil_noise;
	Ref<ZN_FastNoiseLite> outcrop_noise;
	Ref<ZN_FastNoiseLite> continentalness_noise;

	Ref<Curve> height_curve;

	float block_type_period = 64.0f;
	float terrain_period = 80.0f;
	float cave_period = 250.0f;
	float biome_period = 100.0f;
	float soil_period = 40.0f;
	float outcrop_period = 12.0f;
	float continentalness_period = 500.0f;

	float cave_cutoff = 0.3f;
	float cave_coast_clearance = 32.0f;
	float cave_ocean_seal_depth = 24.0f;
	float outcrop_cutoff = 0.75f;

	int block_type_seed = 0;
	int terrain_seed = 0;
	int cave_seed = 0;
	int biome_seed = 0;
	int soil_seed = 0;
	int outcrop_seed = 0;
	int continentalness_seed = 0;

	float rock_slope_threshold = 1.2f;
	float slope_soil_start = 0.5f;

	float base_roughness = 2.0f;

	// Land roughness is suppressed near sea level AND wherever the bare curve shape is already steep,
	// so no biome's amplitude (present or future) can ever turn a coastline into a cliff.
	float coast_margin_start = 5.0f;
	float coast_margin_end = 40.0f;
	float coast_slope_taper_start = 0.3f;
	float coast_slope_taper_end = 1.2f;

	float snow_height = 208.0f;
	float snow_height_variance = 20.0f;
	float snow_depth = 4.0f;

	float gravel_depth_min = 0.0f;
	float gravel_depth_max = 3.0f;

	int ore_min_depth = 4;
	float ore_cutoff = 0.6f;

	float border_variance_period = 300.0f;
	float border_sharpness_min = 0.3f;
	float border_sharpness_max = 2.5f;

	static constexpr int BLOCK_STONE = 1;
	static constexpr int BLOCK_IRON = 2;
	static constexpr int BLOCK_DIRT = 3;
	static constexpr int BLOCK_GRASS = 4;
	static constexpr int BLOCK_SAND = 5;
	static constexpr int BLOCK_SNOW = 6;
	static constexpr int BLOCK_GRAVEL = 7;
	static constexpr int BLOCK_WATER = 8;

	void set_rock_slope_threshold(float value);
	float get_rock_slope_threshold() const;

	void set_slope_soil_start(float value);
	float get_slope_soil_start() const;

	void set_snow_height(float value);
	float get_snow_height() const;

	void set_snow_height_variance(float value);
	float get_snow_height_variance() const;

	void set_snow_depth(float value);
	float get_snow_depth() const;

	void set_gravel_depth_min(float value);
	float get_gravel_depth_min() const;

	void set_gravel_depth_max(float value);
	float get_gravel_depth_max() const;

	void set_ore_min_depth(int value);
	int get_ore_min_depth() const;

	void set_ore_cutoff(float value);
	float get_ore_cutoff() const;

	void set_border_variance_period(float value);
	float get_border_variance_period() const;

	void set_border_sharpness_min(float value);
	float get_border_sharpness_min() const;

	void set_border_sharpness_max(float value);
	float get_border_sharpness_max() const;

	void set_block_type_period(float value);
	float get_block_type_period() const;

	void set_terrain_period(float value);
	float get_terrain_period() const;

	void set_cave_period(float value);
	float get_cave_period() const;

	void set_biome_period(float value);
	float get_biome_period() const;

	void set_soil_period(float value);
	float get_soil_period() const;

	void set_cave_cutoff(float value);
	float get_cave_cutoff() const;

	void set_cave_coast_clearance(float value);
	float get_cave_coast_clearance() const;

	void set_cave_ocean_seal_depth(float value);
	float get_cave_ocean_seal_depth() const;

	void set_block_type_seed(int value);
	int get_block_type_seed() const;

	void set_terrain_seed(int value);
	int get_terrain_seed() const;

	void set_cave_seed(int value);
	int get_cave_seed() const;

	void set_biome_seed(int value);
	int get_biome_seed() const;

	void set_soil_seed(int value);
	int get_soil_seed() const;

	void set_outcrop_seed(int value);
	int get_outcrop_seed() const;

	void set_outcrop_period(float value);
	float get_outcrop_period() const;

	void set_outcrop_cutoff(float value);
	float get_outcrop_cutoff() const;

	void set_continentalness_seed(int value);
	int get_continentalness_seed() const;

	void set_continentalness_period(float value);
	float get_continentalness_period() const;

	void set_height_curve(Ref<Curve> value);
	Ref<Curve> get_height_curve() const;

	void set_base_roughness(float value);
	float get_base_roughness() const;

	void set_coast_margin_start(float value);
	float get_coast_margin_start() const;

	void set_coast_margin_end(float value);
	float get_coast_margin_end() const;

	void set_coast_slope_taper_start(float value);
	float get_coast_slope_taper_start() const;

	void set_coast_slope_taper_end(float value);
	float get_coast_slope_taper_end() const;

	Array biomes;

	// Blends the amplitude (roughness) of the nearest non-ocean biomes; height itself no longer comes
	// from biomes, so an ocean can never get blended against a mismatched land biome's height.
	float get_blended_land_amplitude(float x,
									 float z,
									 Ref<VoxelBiome> &out_primary_biome,
									 Ref<VoxelBiome> &out_secondary_biome,
									 float &out_secondary_weight) const;

	Ref<VoxelBiome> find_ocean_biome() const;

	void prepare_noise();

protected:
	static void _bind_methods();

public:
	VoxelGeneratorFast();

	Result generate_block(VoxelQueryData input) override;

	int get_used_channels_mask() const override;

	Array get_biomes() const;
	void set_biomes(Array value);

	String VoxelGeneratorFast::get_biome_at(Vector3 world_position) const;
};

} // namespace voxel
} // namespace zylann
