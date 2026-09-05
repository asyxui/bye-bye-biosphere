#include "voxel_generator_fast.h"

#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

namespace zylann {
namespace voxel {

VoxelGeneratorFast::VoxelGeneratorFast() {
	prepare_noise();
}

static inline float lerp(float a, float b, float t) {
	return a + (b - a) * t;
}

// Converts a world-space layer thickness into this LOD's voxel-step units (min 1 when non-zero),
// so a layer keeps roughly the same real-world thickness at every LOD.
static inline int world_thickness_to_steps(float world_thickness, int lod_scale) {
	if (world_thickness <= 0.0f) {
		return 0;
	}
	int steps = static_cast<int>(Math::round(world_thickness / static_cast<float>(lod_scale)));
	return steps < 1 ? 1 : steps;
}

static inline float smoothstep(float edge0, float edge1, float x) {
	float t = (x - edge0) / (edge1 - edge0);
	t = t < 0.0f ? 0.0f : (t > 1.0f ? 1.0f : t);
	return t * t * (3.0f - 2.0f * t);
}

VoxelGenerator::Result VoxelGeneratorFast::generate_block(VoxelQueryData input) {
	Result result;

	VoxelBuffer &out_buffer = input.voxel_buffer;

	const Vector3i origin = input.origin_in_voxels;
	const Vector3i size = out_buffer.get_size();

	const int lod_scale = 1 << input.lod;

	// A single biome (if any) is the ocean; its water level is compared directly against the final
	// computed terrain height below, so the two can never disagree and produce floating/disconnected water.
	Ref<VoxelBiome> ocean_biome = find_ocean_biome();
	const float ocean_water_level = ocean_biome.is_valid() ? ocean_biome->get_water_level() : -1000000.0f;

	for (int z = 0; z < size.z; z++) {
		for (int x = 0; x < size.x; x++) {
			const float world_x = origin.x + x * lod_scale;
			const float world_z = origin.z + z * lod_scale;

			Ref<VoxelBiome> primary_biome;
			Ref<VoxelBiome> secondary_biome;
			float secondary_weight = 0.0f;

			// Amplitude (roughness) only -- height comes from continentalness below, never from biomes.
			const float land_amplitude = get_blended_land_amplitude(
					world_x / biome_period, world_z / biome_period, primary_biome, secondary_biome, secondary_weight);

			const float continentalness = (continentalness_noise->get_noise_2d(world_x, world_z) + 1.0f) * 0.5f;
			const float curve_height = height_curve.is_valid() ? height_curve->sample_baked(continentalness) : 0.0f;

			// Sample the bare curve shape (no biome roughness yet) at neighbors, at this LOD's own voxel
			// spacing, to measure how steep the terrain already is here before any biome adds to it.
			const float slope_step = static_cast<float>(lod_scale);

			const float continentalness_px =
					(continentalness_noise->get_noise_2d(world_x + slope_step, world_z) + 1.0f) * 0.5f;
			const float continentalness_nx =
					(continentalness_noise->get_noise_2d(world_x - slope_step, world_z) + 1.0f) * 0.5f;
			const float continentalness_pz =
					(continentalness_noise->get_noise_2d(world_x, world_z + slope_step) + 1.0f) * 0.5f;
			const float continentalness_nz =
					(continentalness_noise->get_noise_2d(world_x, world_z - slope_step) + 1.0f) * 0.5f;

			const float curve_px = height_curve.is_valid() ? height_curve->sample_baked(continentalness_px) : 0.0f;
			const float curve_nx = height_curve.is_valid() ? height_curve->sample_baked(continentalness_nx) : 0.0f;
			const float curve_pz = height_curve.is_valid() ? height_curve->sample_baked(continentalness_pz) : 0.0f;
			const float curve_nz = height_curve.is_valid() ? height_curve->sample_baked(continentalness_nz) : 0.0f;

			const float base_slope_x = Math::abs(curve_px - curve_nx) / (2.0f * slope_step);
			const float base_slope_z = Math::abs(curve_pz - curve_nz) / (2.0f * slope_step);
			const float base_slope = base_slope_x > base_slope_z ? base_slope_x : base_slope_z;

			// Land roughness is suppressed both near sea level (by height, not by an arbitrary noise
			// value) AND wherever the bare curve is already steep for any reason -- so no biome's
			// amplitude, present or future, can ever compound on top of an already-steep coastline.
			const float coast_margin_taper =
					smoothstep(coast_margin_start, coast_margin_end, curve_height - ocean_water_level);
			const float coast_slope_taper =
					1.0f - smoothstep(coast_slope_taper_start, coast_slope_taper_end, base_slope);
			const float effective_amplitude = base_roughness + land_amplitude * coast_margin_taper * coast_slope_taper;

			const float terrain_height =
					curve_height + effective_amplitude * terrain_noise->get_noise_2d(world_x, world_z);

			// Central difference at this LOD's own voxel spacing, so slope readings stay
			// consistent across LODs and aren't biased towards the +x/+z directions. Reuses this
			// column's amplitude instead of re-blending biomes at each neighbor sample.
			const float height_px =
					curve_px + effective_amplitude * terrain_noise->get_noise_2d(world_x + slope_step, world_z);
			const float height_nx =
					curve_nx + effective_amplitude * terrain_noise->get_noise_2d(world_x - slope_step, world_z);
			const float height_pz =
					curve_pz + effective_amplitude * terrain_noise->get_noise_2d(world_x, world_z + slope_step);
			const float height_nz =
					curve_nz + effective_amplitude * terrain_noise->get_noise_2d(world_x, world_z - slope_step);

			const float slope_x = Math::abs(height_px - height_nx) / (2.0f * slope_step);
			const float slope_z = Math::abs(height_pz - height_nz) / (2.0f * slope_step);
			const float slope = slope_x > slope_z ? slope_x : slope_z;

			// Soil thins out gradually on slopes instead of an abrupt cutoff, fully bare by rock_slope_threshold.
			float soil_scale = 1.0f;
			if (slope > slope_soil_start) {
				const float falloff_range = rock_slope_threshold - slope_soil_start;
				soil_scale = falloff_range > 0.001f ? 1.0f - (slope - slope_soil_start) / falloff_range : 0.0f;
				if (soil_scale < 0.0f)
					soil_scale = 0.0f;
			}

			const int surface_y = static_cast<int>(Math::floor(terrain_height));

			int surface_type = primary_biome.is_valid() ? primary_biome->get_surface_voxel_type()
														: static_cast<int>(VoxelBiome::SURFACE_ROCK);

			Ref<VoxelBiome> soil_source_biome = primary_biome;

			// Dither with the secondary biome near borders instead of a hard material line.
			// A slow-varying field (independent of the biome layout) makes some borders sharp and others scattered.
			if (secondary_biome.is_valid() && secondary_weight > 0.01f) {
				const float variance_t = biome_noise->get_noise_2d(world_x / border_variance_period + 1000.0f,
																   world_z / border_variance_period + 1000.0f);
				const float sharpness_scale =
						lerp(border_sharpness_min, border_sharpness_max, (variance_t + 1.0f) * 0.5f);

				float effective_weight = secondary_weight * sharpness_scale;
				if (effective_weight > 1.0f)
					effective_weight = 1.0f;

				const float dither_t = (outcrop_noise->get_noise_2d(world_x, world_z) + 1.0f) * 0.5f;
				if (dither_t < effective_weight) {
					surface_type = secondary_biome->get_surface_voxel_type();
					soil_source_biome = secondary_biome;
				}
			}

			// Underwater always shows the ocean's own seabed material, regardless of which land biome
			// would otherwise apply -- and "underwater" is the exact same terrain_height used for
			// everything else, so this can never disagree with where water actually gets placed below.
			const bool is_water_here = ocean_biome.is_valid() && terrain_height < ocean_water_level;
			if (is_water_here) {
				surface_type = ocean_biome->get_surface_voxel_type();
				soil_source_biome = ocean_biome;
			}

			float soil_depth_world = 0.0f;
			if (soil_source_biome.is_valid()) {
				const float soil_t = (soil_noise->get_noise_2d(world_x, world_z) + 1.0f) * 0.5f;
				soil_depth_world =
						lerp(soil_source_biome->get_soil_depth_min(), soil_source_biome->get_soil_depth_max(), soil_t);
			}
			soil_depth_world *= soil_scale;

			int layer_top_block;
			int layer_sub_block;

			switch (surface_type) {
				case VoxelBiome::SURFACE_SAND:
					layer_top_block = BLOCK_SAND;
					layer_sub_block = BLOCK_SAND;
					break;
				case VoxelBiome::SURFACE_ROCK:
					layer_top_block = BLOCK_STONE;
					layer_sub_block = BLOCK_STONE;
					break;
				case VoxelBiome::SURFACE_GRASS:
				default:
					layer_top_block = BLOCK_GRASS;
					layer_sub_block = BLOCK_DIRT;
					break;
			}

			float layer_depth_world = soil_depth_world;

			// Snow caps override everything else near mountain peaks, with a jittered tree line.
			const float snow_jitter = soil_noise->get_noise_2d(world_x + 500.0f, world_z + 500.0f);
			const float effective_snow_height = snow_height + snow_jitter * snow_height_variance;

			if (!is_water_here && terrain_height > effective_snow_height) {
				layer_top_block = BLOCK_SNOW;
				layer_sub_block = BLOCK_SNOW;
				layer_depth_world = snow_depth * soil_scale;
			}

			const int layer_depth_steps = world_thickness_to_steps(layer_depth_world, lod_scale);

			// Reuse soil_noise at an offset so gravel thickness varies independently of soil depth.
			const float gravel_t = (soil_noise->get_noise_2d(world_x + 2000.0f, world_z + 2000.0f) + 1.0f) * 0.5f;
			const float gravel_depth_world = lerp(gravel_depth_min, gravel_depth_max, gravel_t) * soil_scale;
			const int gravel_depth_steps = world_thickness_to_steps(gravel_depth_world, lod_scale);

			const float coast_seal_weight =
					1.0f - smoothstep(0.0f, cave_coast_clearance, terrain_height - ocean_water_level);
			const float required_cave_roof = cave_ocean_seal_depth * coast_seal_weight;

			for (int y = 0; y < size.y; y++) {
				const int world_y = origin.y + y * lod_scale;
				const bool is_ocean_surface_cell =
						is_water_here && world_y < ocean_water_level && world_y + lod_scale >= ocean_water_level;

				// Ocean water is a surface shell, not a filled volume. Keeping only the cell that touches sea
				// level prevents exposed chunk or LOD boundaries from becoming deep vertical walls of water.
				if (is_ocean_surface_cell) {
					out_buffer.set_voxel(BLOCK_WATER, x, y, z, VoxelBuffer::CHANNEL_TYPE);
					continue;
				}

				if (world_y > terrain_height) {
					if (is_water_here && world_y < ocean_water_level) {
						out_buffer.set_voxel(BLOCK_WATER, x, y, z, VoxelBuffer::CHANNEL_TYPE);
					}
					continue;
				}

				const float depth_below_surface = terrain_height - static_cast<float>(world_y);
				const bool cave_is_below_seal = depth_below_surface >= required_cave_roof;
				if (cave_is_below_seal && cave_noise->get_noise_3d(world_x, world_y, world_z) >= cave_cutoff) {
					continue;
				}

				// Measured in voxel steps (not world units), so the surface layer stays 1 voxel thick at every LOD.
				const int depth = (surface_y - world_y) / lod_scale;

				int voxel_type;

				if (depth < layer_depth_steps) {
					voxel_type = (depth == 0) ? layer_top_block : layer_sub_block;

					// Scattered rock outcrops poking through the soil/snow layer.
					if (outcrop_noise->get_noise_3d(world_x, world_y, world_z) > outcrop_cutoff) {
						voxel_type = BLOCK_STONE;
					}
				} else if (depth < layer_depth_steps + gravel_depth_steps) {
					voxel_type = BLOCK_GRAVEL;
				} else if (depth >= ore_min_depth &&
						   block_type_noise->get_noise_3d(world_x, world_y, world_z) > ore_cutoff) {
					voxel_type = BLOCK_IRON;
				} else {
					voxel_type = BLOCK_STONE;
				}

				out_buffer.set_voxel(voxel_type, x, y, z, VoxelBuffer::CHANNEL_TYPE);
			}
		}
	}

	return result;
}

void VoxelGeneratorFast::prepare_noise() {
	block_type_noise.instantiate();
	terrain_noise.instantiate();
	cave_noise.instantiate();
	biome_noise.instantiate();
	soil_noise.instantiate();
	outcrop_noise.instantiate();
	continentalness_noise.instantiate();

	block_type_noise->set_noise_type(ZN_FastNoiseLite::TYPE_OPEN_SIMPLEX_2);

	block_type_noise->set_seed(block_type_seed);
	block_type_noise->set_period(block_type_period);

	terrain_noise->set_noise_type(ZN_FastNoiseLite::TYPE_VALUE_CUBIC);

	terrain_noise->set_seed(terrain_seed);
	terrain_noise->set_period(terrain_period);

	terrain_noise->set_fractal_type(ZN_FastNoiseLite::FRACTAL_FBM);

	terrain_noise->set_fractal_octaves(2);
	terrain_noise->set_fractal_lacunarity(2.0f);
	terrain_noise->set_fractal_gain(0.5f);

	cave_noise->set_noise_type(ZN_FastNoiseLite::TYPE_OPEN_SIMPLEX_2);

	cave_noise->set_seed(cave_seed);
	cave_noise->set_period(cave_period);

	cave_noise->set_fractal_type(ZN_FastNoiseLite::FRACTAL_FBM);

	cave_noise->set_fractal_octaves(1);
	cave_noise->set_fractal_lacunarity(2.0f);
	cave_noise->set_fractal_gain(0.5f);

	biome_noise->set_noise_type(ZN_FastNoiseLite::TYPE_OPEN_SIMPLEX_2);

	biome_noise->set_seed(biome_seed);
	biome_noise->set_period(biome_period);

	soil_noise->set_noise_type(ZN_FastNoiseLite::TYPE_OPEN_SIMPLEX_2);

	soil_noise->set_seed(soil_seed);
	soil_noise->set_period(soil_period);

	outcrop_noise->set_noise_type(ZN_FastNoiseLite::TYPE_OPEN_SIMPLEX_2);

	outcrop_noise->set_seed(outcrop_seed);
	outcrop_noise->set_period(outcrop_period);

	continentalness_noise->set_noise_type(ZN_FastNoiseLite::TYPE_OPEN_SIMPLEX_2);

	continentalness_noise->set_seed(continentalness_seed);
	continentalness_noise->set_period(continentalness_period);

	// ZN_FastNoiseLite defaults to 3-octave FBM, which injects steep local high-frequency detail --
	// continentalness must be a single smooth layer, or its slope near the coast is unbounded.
	continentalness_noise->set_fractal_type(ZN_FastNoiseLite::FRACTAL_NONE);

	// Sensible default so the terrain works out of the box; assign a custom Curve in the inspector to override.
	if (!height_curve.is_valid()) {
		height_curve.instantiate();
		height_curve->set_min_value(-72.0f);
		height_curve->set_max_value(300.0f);
		height_curve->add_point(Vector2(0.0f, -62.0f));
		height_curve->add_point(Vector2(0.35f, -20.0f));
		height_curve->add_point(Vector2(0.5f, 0.0f));
		height_curve->add_point(Vector2(0.6f, 18.0f));
		height_curve->add_point(Vector2(0.8f, 78.0f));
		height_curve->add_point(Vector2(1.0f, 188.0f));
	}
}

float VoxelGeneratorFast::get_blended_land_amplitude(float x,
													 float z,
													 Ref<VoxelBiome> &out_primary_biome,
													 Ref<VoxelBiome> &out_secondary_biome,
													 float &out_secondary_weight) const {
	float t = (biome_noise->get_noise_2d(x, z) + 1.0f) * 0.5f;

	Ref<VoxelBiome> primary_biome;
	Ref<VoxelBiome> secondary_biome;

	float best_weight = -1000.0f;
	float secondary_weight = -1000.0f;

	for (Variant v : biomes) {
		Ref<VoxelBiome> biome = v;

		// The ocean is selected by continentalness alone, not this land-character contest.
		if (biome.is_null() || biome->get_is_ocean())
			continue;

		float dist = Math::abs(t - biome->get_threshold_center());

		float weight = 1.0f / Math::pow(dist + 0.001f, 2.0f);

		if (weight > best_weight) {
			secondary_weight = best_weight;
			secondary_biome = primary_biome;

			best_weight = weight;
			primary_biome = biome;
		} else if (weight > secondary_weight) {
			secondary_weight = weight;
			secondary_biome = biome;
		}
	}

	if (primary_biome.is_null())
		return 0.0f;

	out_primary_biome = primary_biome;

	if (secondary_biome.is_null()) {
		return primary_biome->get_terrain_amplitude();
	}

	float total = best_weight + secondary_weight;

	float ta = best_weight / total;
	float tb = secondary_weight / total;

	out_secondary_biome = secondary_biome;
	out_secondary_weight = tb;

	return primary_biome->get_terrain_amplitude() * ta + secondary_biome->get_terrain_amplitude() * tb;
}

Ref<VoxelBiome> VoxelGeneratorFast::find_ocean_biome() const {
	for (Variant v : biomes) {
		Ref<VoxelBiome> biome = v;
		if (biome.is_valid() && biome->get_is_ocean()) {
			return biome;
		}
	}
	return Ref<VoxelBiome>();
}

int VoxelGeneratorFast::get_used_channels_mask() const {
	return 1 << VoxelBuffer::CHANNEL_TYPE;
}

Array VoxelGeneratorFast::get_biomes() const {
	return biomes;
}

void VoxelGeneratorFast::set_biomes(Array value) {
	biomes = value;
}

void VoxelGeneratorFast::set_block_type_period(float value) {
	block_type_period = value;

	if (block_type_noise.is_valid())
		block_type_noise->set_period(value);
}

float VoxelGeneratorFast::get_block_type_period() const {
	return block_type_period;
}

void VoxelGeneratorFast::set_terrain_period(float value) {
	terrain_period = value;

	if (terrain_noise.is_valid())
		terrain_noise->set_period(value);
}

float VoxelGeneratorFast::get_terrain_period() const {
	return terrain_period;
}

void VoxelGeneratorFast::set_cave_period(float value) {
	cave_period = value;

	if (cave_noise.is_valid())
		cave_noise->set_period(value);
}

float VoxelGeneratorFast::get_cave_period() const {
	return cave_period;
}

void VoxelGeneratorFast::set_biome_period(float value) {
	biome_period = value;

	if (biome_noise.is_valid())
		biome_noise->set_period(value);
}

float VoxelGeneratorFast::get_biome_period() const {
	return biome_period;
}

void VoxelGeneratorFast::set_soil_period(float value) {
	soil_period = value;

	if (soil_noise.is_valid())
		soil_noise->set_period(value);
}

float VoxelGeneratorFast::get_soil_period() const {
	return soil_period;
}

void VoxelGeneratorFast::set_outcrop_period(float value) {
	outcrop_period = value;

	if (outcrop_noise.is_valid())
		outcrop_noise->set_period(value);
}

float VoxelGeneratorFast::get_outcrop_period() const {
	return outcrop_period;
}

float VoxelGeneratorFast::get_outcrop_cutoff() const {
	return outcrop_cutoff;
}

void VoxelGeneratorFast::set_outcrop_cutoff(float value) {
	outcrop_cutoff = value;
}

void VoxelGeneratorFast::set_continentalness_seed(int value) {
	continentalness_seed = value;

	if (continentalness_noise.is_valid())
		continentalness_noise->set_seed(value);
}

int VoxelGeneratorFast::get_continentalness_seed() const {
	return continentalness_seed;
}

void VoxelGeneratorFast::set_continentalness_period(float value) {
	continentalness_period = value;

	if (continentalness_noise.is_valid())
		continentalness_noise->set_period(value);
}

float VoxelGeneratorFast::get_continentalness_period() const {
	return continentalness_period;
}

void VoxelGeneratorFast::set_height_curve(Ref<Curve> value) {
	height_curve = value;
}

Ref<Curve> VoxelGeneratorFast::get_height_curve() const {
	return height_curve;
}

void VoxelGeneratorFast::set_base_roughness(float value) {
	base_roughness = value;
}

float VoxelGeneratorFast::get_base_roughness() const {
	return base_roughness;
}

void VoxelGeneratorFast::set_coast_margin_start(float value) {
	coast_margin_start = value;
}

float VoxelGeneratorFast::get_coast_margin_start() const {
	return coast_margin_start;
}

void VoxelGeneratorFast::set_coast_margin_end(float value) {
	coast_margin_end = value;
}

float VoxelGeneratorFast::get_coast_margin_end() const {
	return coast_margin_end;
}

void VoxelGeneratorFast::set_coast_slope_taper_start(float value) {
	coast_slope_taper_start = value;
}

float VoxelGeneratorFast::get_coast_slope_taper_start() const {
	return coast_slope_taper_start;
}

void VoxelGeneratorFast::set_coast_slope_taper_end(float value) {
	coast_slope_taper_end = value;
}

float VoxelGeneratorFast::get_coast_slope_taper_end() const {
	return coast_slope_taper_end;
}

float VoxelGeneratorFast::get_cave_cutoff() const {
	return cave_cutoff;
}

void VoxelGeneratorFast::set_cave_cutoff(float value) {
	cave_cutoff = value;
}

float VoxelGeneratorFast::get_cave_coast_clearance() const {
	return cave_coast_clearance;
}

void VoxelGeneratorFast::set_cave_coast_clearance(float value) {
	cave_coast_clearance = Math::max(value, 0.0f);
}

float VoxelGeneratorFast::get_cave_ocean_seal_depth() const {
	return cave_ocean_seal_depth;
}

void VoxelGeneratorFast::set_cave_ocean_seal_depth(float value) {
	cave_ocean_seal_depth = Math::max(value, 0.0f);
}

float VoxelGeneratorFast::get_rock_slope_threshold() const {
	return rock_slope_threshold;
}

void VoxelGeneratorFast::set_rock_slope_threshold(float value) {
	rock_slope_threshold = value;
}

float VoxelGeneratorFast::get_slope_soil_start() const {
	return slope_soil_start;
}

void VoxelGeneratorFast::set_slope_soil_start(float value) {
	slope_soil_start = value;
}

float VoxelGeneratorFast::get_snow_height() const {
	return snow_height;
}

void VoxelGeneratorFast::set_snow_height(float value) {
	snow_height = value;
}

float VoxelGeneratorFast::get_snow_height_variance() const {
	return snow_height_variance;
}

void VoxelGeneratorFast::set_snow_height_variance(float value) {
	snow_height_variance = value;
}

float VoxelGeneratorFast::get_snow_depth() const {
	return snow_depth;
}

void VoxelGeneratorFast::set_snow_depth(float value) {
	snow_depth = value;
}

float VoxelGeneratorFast::get_gravel_depth_min() const {
	return gravel_depth_min;
}

void VoxelGeneratorFast::set_gravel_depth_min(float value) {
	gravel_depth_min = value;
}

float VoxelGeneratorFast::get_gravel_depth_max() const {
	return gravel_depth_max;
}

void VoxelGeneratorFast::set_gravel_depth_max(float value) {
	gravel_depth_max = value;
}

int VoxelGeneratorFast::get_ore_min_depth() const {
	return ore_min_depth;
}

void VoxelGeneratorFast::set_ore_min_depth(int value) {
	ore_min_depth = value;
}

float VoxelGeneratorFast::get_ore_cutoff() const {
	return ore_cutoff;
}

void VoxelGeneratorFast::set_ore_cutoff(float value) {
	ore_cutoff = value;
}

float VoxelGeneratorFast::get_border_variance_period() const {
	return border_variance_period;
}

void VoxelGeneratorFast::set_border_variance_period(float value) {
	border_variance_period = value;
}

float VoxelGeneratorFast::get_border_sharpness_min() const {
	return border_sharpness_min;
}

void VoxelGeneratorFast::set_border_sharpness_min(float value) {
	border_sharpness_min = value;
}

float VoxelGeneratorFast::get_border_sharpness_max() const {
	return border_sharpness_max;
}

void VoxelGeneratorFast::set_border_sharpness_max(float value) {
	border_sharpness_max = value;
}

void VoxelGeneratorFast::set_block_type_seed(int value) {
	block_type_seed = value;

	if (block_type_noise.is_valid())
		block_type_noise->set_seed(value);
}

int VoxelGeneratorFast::get_block_type_seed() const {
	return block_type_seed;
}

void VoxelGeneratorFast::set_terrain_seed(int value) {
	terrain_seed = value;

	if (terrain_noise.is_valid())
		terrain_noise->set_seed(value);
}

int VoxelGeneratorFast::get_terrain_seed() const {
	return terrain_seed;
}

void VoxelGeneratorFast::set_cave_seed(int value) {
	cave_seed = value;

	if (cave_noise.is_valid())
		cave_noise->set_seed(value);
}

int VoxelGeneratorFast::get_cave_seed() const {
	return cave_seed;
}

void VoxelGeneratorFast::set_biome_seed(int value) {
	biome_seed = value;

	if (biome_noise.is_valid())
		biome_noise->set_seed(value);
}

int VoxelGeneratorFast::get_biome_seed() const {
	return biome_seed;
}

void VoxelGeneratorFast::set_soil_seed(int value) {
	soil_seed = value;

	if (soil_noise.is_valid())
		soil_noise->set_seed(value);
}

int VoxelGeneratorFast::get_soil_seed() const {
	return soil_seed;
}

void VoxelGeneratorFast::set_outcrop_seed(int value) {
	outcrop_seed = value;

	if (outcrop_noise.is_valid())
		outcrop_noise->set_seed(value);
}

int VoxelGeneratorFast::get_outcrop_seed() const {
	return outcrop_seed;
}

String VoxelGeneratorFast::get_biome_at(Vector3 world_position) const {
	Ref<VoxelBiome> ocean = find_ocean_biome();
	if (ocean.is_valid()) {
		const float continentalness_here =
				(continentalness_noise->get_noise_2d(world_position.x, world_position.z) + 1.0f) * 0.5f;
		const float approx_height = height_curve.is_valid() ? height_curve->sample_baked(continentalness_here) : 0.0f;
		if (approx_height < ocean->get_water_level()) {
			return ocean->get_biome_name() + " (submerged)";
		}
	}

	const float x = world_position.x / biome_period;
	const float z = world_position.z / biome_period;

	const float t = (biome_noise->get_noise_2d(x, z) + 1.0f) * 0.5f;

	Ref<VoxelBiome> primary_biome;
	Ref<VoxelBiome> secondary_biome;

	float primary_weight = -1000.0f;
	float secondary_weight = -1000.0f;

	for (Variant v : biomes) {
		Ref<VoxelBiome> biome = v;

		if (biome.is_null() || biome->get_is_ocean())
			continue;

		const float dist = Math::abs(t - biome->get_threshold_center());

		const float weight = 1.0f / Math::pow(dist + 0.001f, 2.0f);

		if (weight > primary_weight) {
			secondary_weight = primary_weight;
			secondary_biome = primary_biome;

			primary_weight = weight;
			primary_biome = biome;
		} else if (weight > secondary_weight) {
			secondary_weight = weight;
			secondary_biome = biome;
		}
	}

	if (primary_biome.is_null())
		return "None";

	if (secondary_biome.is_null())
		return primary_biome->get_biome_name() + " (100%)";

	const float total_weight = primary_weight + secondary_weight;

	const float primary_percentage = primary_weight / total_weight * 100.0f;

	const float secondary_percentage = secondary_weight / total_weight * 100.0f;

	return vformat("%s (%.1f%%), %s (%.1f%%), threshold: %f",
				   primary_biome->get_biome_name(),
				   primary_percentage,
				   secondary_biome->get_biome_name(),
				   secondary_percentage,
				   t);
}

void VoxelGeneratorFast::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_biomes", "value"), &VoxelGeneratorFast::set_biomes);

	ClassDB::bind_method(D_METHOD("get_biomes"), &VoxelGeneratorFast::get_biomes);

	ClassDB::bind_method(D_METHOD("set_block_type_period", "value"), &VoxelGeneratorFast::set_block_type_period);

	ClassDB::bind_method(D_METHOD("get_block_type_period"), &VoxelGeneratorFast::get_block_type_period);

	ClassDB::bind_method(D_METHOD("set_terrain_period", "value"), &VoxelGeneratorFast::set_terrain_period);

	ClassDB::bind_method(D_METHOD("get_terrain_period"), &VoxelGeneratorFast::get_terrain_period);

	ClassDB::bind_method(D_METHOD("set_cave_period", "value"), &VoxelGeneratorFast::set_cave_period);

	ClassDB::bind_method(D_METHOD("get_cave_period"), &VoxelGeneratorFast::get_cave_period);

	ClassDB::bind_method(D_METHOD("set_biome_period", "value"), &VoxelGeneratorFast::set_biome_period);

	ClassDB::bind_method(D_METHOD("get_biome_period"), &VoxelGeneratorFast::get_biome_period);

	ClassDB::bind_method(D_METHOD("set_soil_period", "value"), &VoxelGeneratorFast::set_soil_period);

	ClassDB::bind_method(D_METHOD("get_soil_period"), &VoxelGeneratorFast::get_soil_period);

	ClassDB::bind_method(D_METHOD("set_cave_cutoff", "value"), &VoxelGeneratorFast::set_cave_cutoff);

	ClassDB::bind_method(D_METHOD("get_cave_cutoff"), &VoxelGeneratorFast::get_cave_cutoff);

	ClassDB::bind_method(D_METHOD("set_rock_slope_threshold", "value"), &VoxelGeneratorFast::set_rock_slope_threshold);

	ClassDB::bind_method(D_METHOD("get_rock_slope_threshold"), &VoxelGeneratorFast::get_rock_slope_threshold);

	ClassDB::bind_method(D_METHOD("get_biome_at", "world_position"), &VoxelGeneratorFast::get_biome_at);

	ClassDB::bind_method(D_METHOD("set_block_type_seed", "value"), &VoxelGeneratorFast::set_block_type_seed);
	ClassDB::bind_method(D_METHOD("get_block_type_seed"), &VoxelGeneratorFast::get_block_type_seed);

	ClassDB::bind_method(D_METHOD("set_terrain_seed", "value"), &VoxelGeneratorFast::set_terrain_seed);
	ClassDB::bind_method(D_METHOD("get_terrain_seed"), &VoxelGeneratorFast::get_terrain_seed);

	ClassDB::bind_method(D_METHOD("set_cave_seed", "value"), &VoxelGeneratorFast::set_cave_seed);
	ClassDB::bind_method(D_METHOD("get_cave_seed"), &VoxelGeneratorFast::get_cave_seed);

	ClassDB::bind_method(D_METHOD("set_biome_seed", "value"), &VoxelGeneratorFast::set_biome_seed);
	ClassDB::bind_method(D_METHOD("get_biome_seed"), &VoxelGeneratorFast::get_biome_seed);

	ClassDB::bind_method(D_METHOD("set_soil_seed", "value"), &VoxelGeneratorFast::set_soil_seed);
	ClassDB::bind_method(D_METHOD("get_soil_seed"), &VoxelGeneratorFast::get_soil_seed);

	ClassDB::bind_method(D_METHOD("set_outcrop_seed", "value"), &VoxelGeneratorFast::set_outcrop_seed);
	ClassDB::bind_method(D_METHOD("get_outcrop_seed"), &VoxelGeneratorFast::get_outcrop_seed);

	ClassDB::bind_method(D_METHOD("set_outcrop_period", "value"), &VoxelGeneratorFast::set_outcrop_period);
	ClassDB::bind_method(D_METHOD("get_outcrop_period"), &VoxelGeneratorFast::get_outcrop_period);

	ClassDB::bind_method(D_METHOD("set_outcrop_cutoff", "value"), &VoxelGeneratorFast::set_outcrop_cutoff);
	ClassDB::bind_method(D_METHOD("get_outcrop_cutoff"), &VoxelGeneratorFast::get_outcrop_cutoff);

	ClassDB::bind_method(D_METHOD("set_continentalness_seed", "value"), &VoxelGeneratorFast::set_continentalness_seed);
	ClassDB::bind_method(D_METHOD("get_continentalness_seed"), &VoxelGeneratorFast::get_continentalness_seed);

	ClassDB::bind_method(D_METHOD("set_continentalness_period", "value"),
						 &VoxelGeneratorFast::set_continentalness_period);
	ClassDB::bind_method(D_METHOD("get_continentalness_period"), &VoxelGeneratorFast::get_continentalness_period);

	ClassDB::bind_method(D_METHOD("set_height_curve", "value"), &VoxelGeneratorFast::set_height_curve);
	ClassDB::bind_method(D_METHOD("get_height_curve"), &VoxelGeneratorFast::get_height_curve);

	ClassDB::bind_method(D_METHOD("set_base_roughness", "value"), &VoxelGeneratorFast::set_base_roughness);
	ClassDB::bind_method(D_METHOD("get_base_roughness"), &VoxelGeneratorFast::get_base_roughness);

	ClassDB::bind_method(D_METHOD("set_coast_margin_start", "value"), &VoxelGeneratorFast::set_coast_margin_start);
	ClassDB::bind_method(D_METHOD("get_coast_margin_start"), &VoxelGeneratorFast::get_coast_margin_start);

	ClassDB::bind_method(D_METHOD("set_coast_margin_end", "value"), &VoxelGeneratorFast::set_coast_margin_end);
	ClassDB::bind_method(D_METHOD("get_coast_margin_end"), &VoxelGeneratorFast::get_coast_margin_end);

	ClassDB::bind_method(D_METHOD("set_coast_slope_taper_start", "value"),
						 &VoxelGeneratorFast::set_coast_slope_taper_start);
	ClassDB::bind_method(D_METHOD("get_coast_slope_taper_start"), &VoxelGeneratorFast::get_coast_slope_taper_start);

	ClassDB::bind_method(D_METHOD("set_coast_slope_taper_end", "value"),
						 &VoxelGeneratorFast::set_coast_slope_taper_end);
	ClassDB::bind_method(D_METHOD("get_coast_slope_taper_end"), &VoxelGeneratorFast::get_coast_slope_taper_end);

	ClassDB::bind_method(D_METHOD("set_cave_coast_clearance", "value"), &VoxelGeneratorFast::set_cave_coast_clearance);
	ClassDB::bind_method(D_METHOD("get_cave_coast_clearance"), &VoxelGeneratorFast::get_cave_coast_clearance);

	ClassDB::bind_method(D_METHOD("set_cave_ocean_seal_depth", "value"),
						 &VoxelGeneratorFast::set_cave_ocean_seal_depth);
	ClassDB::bind_method(D_METHOD("get_cave_ocean_seal_depth"), &VoxelGeneratorFast::get_cave_ocean_seal_depth);

	ClassDB::bind_method(D_METHOD("set_slope_soil_start", "value"), &VoxelGeneratorFast::set_slope_soil_start);
	ClassDB::bind_method(D_METHOD("get_slope_soil_start"), &VoxelGeneratorFast::get_slope_soil_start);

	ClassDB::bind_method(D_METHOD("set_snow_height", "value"), &VoxelGeneratorFast::set_snow_height);
	ClassDB::bind_method(D_METHOD("get_snow_height"), &VoxelGeneratorFast::get_snow_height);

	ClassDB::bind_method(D_METHOD("set_snow_height_variance", "value"), &VoxelGeneratorFast::set_snow_height_variance);
	ClassDB::bind_method(D_METHOD("get_snow_height_variance"), &VoxelGeneratorFast::get_snow_height_variance);

	ClassDB::bind_method(D_METHOD("set_snow_depth", "value"), &VoxelGeneratorFast::set_snow_depth);
	ClassDB::bind_method(D_METHOD("get_snow_depth"), &VoxelGeneratorFast::get_snow_depth);

	ClassDB::bind_method(D_METHOD("set_gravel_depth_min", "value"), &VoxelGeneratorFast::set_gravel_depth_min);
	ClassDB::bind_method(D_METHOD("get_gravel_depth_min"), &VoxelGeneratorFast::get_gravel_depth_min);

	ClassDB::bind_method(D_METHOD("set_gravel_depth_max", "value"), &VoxelGeneratorFast::set_gravel_depth_max);
	ClassDB::bind_method(D_METHOD("get_gravel_depth_max"), &VoxelGeneratorFast::get_gravel_depth_max);

	ClassDB::bind_method(D_METHOD("set_ore_min_depth", "value"), &VoxelGeneratorFast::set_ore_min_depth);
	ClassDB::bind_method(D_METHOD("get_ore_min_depth"), &VoxelGeneratorFast::get_ore_min_depth);

	ClassDB::bind_method(D_METHOD("set_ore_cutoff", "value"), &VoxelGeneratorFast::set_ore_cutoff);
	ClassDB::bind_method(D_METHOD("get_ore_cutoff"), &VoxelGeneratorFast::get_ore_cutoff);

	ClassDB::bind_method(D_METHOD("set_border_variance_period", "value"),
						 &VoxelGeneratorFast::set_border_variance_period);
	ClassDB::bind_method(D_METHOD("get_border_variance_period"), &VoxelGeneratorFast::get_border_variance_period);

	ClassDB::bind_method(D_METHOD("set_border_sharpness_min", "value"), &VoxelGeneratorFast::set_border_sharpness_min);
	ClassDB::bind_method(D_METHOD("get_border_sharpness_min"), &VoxelGeneratorFast::get_border_sharpness_min);

	ClassDB::bind_method(D_METHOD("set_border_sharpness_max", "value"), &VoxelGeneratorFast::set_border_sharpness_max);
	ClassDB::bind_method(D_METHOD("get_border_sharpness_max"), &VoxelGeneratorFast::get_border_sharpness_max);

	ADD_PROPERTY(
			PropertyInfo(Variant::ARRAY, "biomes", PROPERTY_HINT_ARRAY_TYPE, "VoxelBiome"), "set_biomes", "get_biomes");

	ADD_GROUP("Noise Parameters", "noise_");

	ADD_PROPERTY(PropertyInfo(Variant::INT, "noise_block_type_seed"), "set_block_type_seed", "get_block_type_seed");

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "noise_block_type_period", PROPERTY_HINT_RANGE, "1.0,500.0,1.0"),
				 "set_block_type_period",
				 "get_block_type_period");

	ADD_PROPERTY(PropertyInfo(Variant::INT, "noise_terrain_seed"), "set_terrain_seed", "get_terrain_seed");

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "noise_terrain_period", PROPERTY_HINT_RANGE, "1.0,500.0,1.0"),
				 "set_terrain_period",
				 "get_terrain_period");

	ADD_PROPERTY(PropertyInfo(Variant::INT, "noise_cave_seed"), "set_cave_seed", "get_cave_seed");

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "noise_cave_period", PROPERTY_HINT_RANGE, "1.0,1000.0,1.0"),
				 "set_cave_period",
				 "get_cave_period");

	ADD_PROPERTY(PropertyInfo(Variant::INT, "noise_biome_seed"), "set_biome_seed", "get_biome_seed");

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "noise_biome_period", PROPERTY_HINT_RANGE, "1.0,500.0,1.0"),
				 "set_biome_period",
				 "get_biome_period");

	ADD_PROPERTY(PropertyInfo(Variant::INT, "noise_soil_seed"), "set_soil_seed", "get_soil_seed");

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "noise_soil_period", PROPERTY_HINT_RANGE, "1.0,500.0,1.0"),
				 "set_soil_period",
				 "get_soil_period");

	ADD_PROPERTY(PropertyInfo(Variant::INT, "noise_outcrop_seed"), "set_outcrop_seed", "get_outcrop_seed");

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "noise_outcrop_period", PROPERTY_HINT_RANGE, "1.0,200.0,1.0"),
				 "set_outcrop_period",
				 "get_outcrop_period");

	ADD_PROPERTY(PropertyInfo(Variant::INT, "noise_continentalness_seed"),
				 "set_continentalness_seed",
				 "get_continentalness_seed");

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "noise_continentalness_period", PROPERTY_HINT_RANGE, "10.0,4000.0,10.0"),
				 "set_continentalness_period",
				 "get_continentalness_period");

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "noise_cave_cutoff", PROPERTY_HINT_RANGE, "0.01,1.0,0.01"),
				 "set_cave_cutoff",
				 "get_cave_cutoff");

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "rock_slope_threshold", PROPERTY_HINT_RANGE, "0.0,5.0,0.05"),
				 "set_rock_slope_threshold",
				 "get_rock_slope_threshold");

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "slope_soil_start", PROPERTY_HINT_RANGE, "0.0,5.0,0.05"),
				 "set_slope_soil_start",
				 "get_slope_soil_start");

	ADD_GROUP("Terrain Shape", "");

	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "height_curve", PROPERTY_HINT_RESOURCE_TYPE, "Curve"),
				 "set_height_curve",
				 "get_height_curve");

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "base_roughness", PROPERTY_HINT_RANGE, "0.0,20.0,0.5"),
				 "set_base_roughness",
				 "get_base_roughness");

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "coast_margin_start", PROPERTY_HINT_RANGE, "-50.0,100.0,1.0"),
				 "set_coast_margin_start",
				 "get_coast_margin_start");

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "coast_margin_end", PROPERTY_HINT_RANGE, "-50.0,200.0,1.0"),
				 "set_coast_margin_end",
				 "get_coast_margin_end");

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "coast_slope_taper_start", PROPERTY_HINT_RANGE, "0.0,5.0,0.05"),
				 "set_coast_slope_taper_start",
				 "get_coast_slope_taper_start");

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "coast_slope_taper_end", PROPERTY_HINT_RANGE, "0.0,5.0,0.05"),
				 "set_coast_slope_taper_end",
				 "get_coast_slope_taper_end");

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "cave_coast_clearance", PROPERTY_HINT_RANGE, "0.0,128.0,1.0"),
				 "set_cave_coast_clearance",
				 "get_cave_coast_clearance");

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "cave_ocean_seal_depth", PROPERTY_HINT_RANGE, "0.0,128.0,1.0"),
				 "set_cave_ocean_seal_depth",
				 "get_cave_ocean_seal_depth");

	ADD_GROUP("Surface Detail", "");

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "outcrop_cutoff", PROPERTY_HINT_RANGE, "0.0,1.0,0.01"),
				 "set_outcrop_cutoff",
				 "get_outcrop_cutoff");

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "snow_height"), "set_snow_height", "get_snow_height");

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "snow_height_variance", PROPERTY_HINT_RANGE, "0.0,100.0,1.0"),
				 "set_snow_height_variance",
				 "get_snow_height_variance");

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "snow_depth", PROPERTY_HINT_RANGE, "0.0,20.0,0.5"),
				 "set_snow_depth",
				 "get_snow_depth");

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "gravel_depth_min", PROPERTY_HINT_RANGE, "0.0,10.0,0.5"),
				 "set_gravel_depth_min",
				 "get_gravel_depth_min");

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "gravel_depth_max", PROPERTY_HINT_RANGE, "0.0,10.0,0.5"),
				 "set_gravel_depth_max",
				 "get_gravel_depth_max");

	ADD_PROPERTY(PropertyInfo(Variant::INT, "ore_min_depth", PROPERTY_HINT_RANGE, "0,20,1"),
				 "set_ore_min_depth",
				 "get_ore_min_depth");

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "ore_cutoff", PROPERTY_HINT_RANGE, "0.0,1.0,0.01"),
				 "set_ore_cutoff",
				 "get_ore_cutoff");
}

} // namespace voxel
} // namespace zylann
