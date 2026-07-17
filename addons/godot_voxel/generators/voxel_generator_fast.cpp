#include "voxel_generator_fast.h"

#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

namespace zylann {
namespace voxel {

VoxelGeneratorFast::VoxelGeneratorFast()
{
	prepare_noise();
}

static inline float lerp(float a, float b, float t)
{
	return a + (b - a) * t;
}

#define BIOME_PERIOD 120.0f

VoxelGenerator::Result VoxelGeneratorFast::generate_block(
	VoxelQueryData input
)
{
	Result result;

	VoxelBuffer &out_buffer = input.voxel_buffer;

	const Vector3i origin = input.origin_in_voxels;
	const Vector3i size = out_buffer.get_size();

	const int lod_scale = 1 << input.lod;

	for (int z = 0; z < size.z; z++)
	{
		for (int x = 0; x < size.x; x++)
		{
			const float world_x = origin.x + x * lod_scale;
			const float world_z = origin.z + z * lod_scale;

			Vector2 biome =
				get_blended_biome(
					world_x / BIOME_PERIOD,
					world_z / BIOME_PERIOD
				);

			float terrain_height =
				biome.x +
				terrain_noise->get_noise_2d(
					world_x,
					world_z
				) * biome.y;

			for (int y = 0; y < size.y; y++)
			{
				const int world_y =	origin.y + y * lod_scale;
				if (world_y > terrain_height) continue;

				if (cave_noise->get_noise_3d(world_x, world_y, world_z) >= 0.3f) continue;

				float block_val = block_type_noise->get_noise_3d(world_x, world_y, world_z);
				out_buffer.set_voxel(block_val > 0.0 ? 2 : 1, x, y, z, VoxelBuffer::CHANNEL_TYPE);
			}
		}
	}

	return result;
}

void VoxelGeneratorFast::prepare_noise()
{
	block_type_noise = memnew(ZN_FastNoiseLite);
	terrain_noise = memnew(ZN_FastNoiseLite);
	cave_noise = memnew(ZN_FastNoiseLite);
	biome_noise = memnew(ZN_FastNoiseLite);


	block_type_noise->set_noise_type(
		ZN_FastNoiseLite::TYPE_OPEN_SIMPLEX_2
	);

	block_type_noise->set_seed(0);
	block_type_noise->set_period(64.0f);



	terrain_noise->set_noise_type(
		ZN_FastNoiseLite::TYPE_VALUE_CUBIC
	);

	terrain_noise->set_seed(0);
	terrain_noise->set_period(80.0f);

	terrain_noise->set_fractal_type(
		ZN_FastNoiseLite::FRACTAL_FBM
	);

	terrain_noise->set_fractal_octaves(2);
	terrain_noise->set_fractal_lacunarity(2.0f);
	terrain_noise->set_fractal_gain(0.5f);



	cave_noise->set_noise_type(
		ZN_FastNoiseLite::TYPE_OPEN_SIMPLEX_2
	);

	cave_noise->set_seed(0);
	cave_noise->set_period(250.0f);

	cave_noise->set_fractal_type(
		ZN_FastNoiseLite::FRACTAL_FBM
	);

	cave_noise->set_fractal_octaves(1);
	cave_noise->set_fractal_lacunarity(2.0f);
	cave_noise->set_fractal_gain(0.5f);



	biome_noise->set_noise_type(
		ZN_FastNoiseLite::TYPE_OPEN_SIMPLEX_2
	);

	biome_noise->set_seed(0);
	biome_noise->set_period(BIOME_PERIOD);
}


Vector2 VoxelGeneratorFast::get_blended_biome(
	float x,
	float z
) const
{
	float t =
		(biome_noise->get_noise_2d(x, z) + 1.0f) * 0.5f;


	Ref<VoxelBiome> primary_biome;
	Ref<VoxelBiome> secondary_biome;


	float best_weight = -1000.0f;
	float secondary_weight = -1000.0f;


	for (Variant v : biomes)
	{
		Ref<VoxelBiome> biome = v;

		if (biome.is_null())
			continue;

		float dist = Math::abs(t - biome->get_threshold_center());

		float weight = 1.0f / Math::pow(dist + 0.001f, 2.0f);

		if (weight > best_weight)
		{
			secondary_weight = best_weight;
			secondary_biome = primary_biome;

			best_weight = weight;
			primary_biome = biome;
		}
		else if (weight > secondary_weight)
		{
			secondary_weight = weight;
			secondary_biome = biome;
		}
	}

	if (primary_biome.is_null())
		return Vector2(0, 0);

	if (secondary_biome.is_null())
	{
		return Vector2(
			primary_biome->get_base_height(),
			primary_biome->get_terrain_amplitude()
		);
	}

	float total = best_weight + secondary_weight;

	float ta = best_weight / total;
	float tb = secondary_weight / total;

	return Vector2(
		primary_biome->get_base_height() * ta +
		secondary_biome->get_base_height() * tb,

		primary_biome->get_terrain_amplitude() * ta +
		secondary_biome->get_terrain_amplitude() * tb
	);
}

int VoxelGeneratorFast::get_used_channels_mask() const
{
	return 1 << VoxelBuffer::CHANNEL_TYPE;
}

Array VoxelGeneratorFast::get_biomes() const
{
	return biomes;
}

void VoxelGeneratorFast::set_biomes(Array value)
{
	biomes = value;
}

void VoxelGeneratorFast::_bind_methods()
{
	ClassDB::bind_method(
	D_METHOD("set_biomes", "value"),
	&VoxelGeneratorFast::set_biomes
	);

	ClassDB::bind_method(
		D_METHOD("get_biomes"),
		&VoxelGeneratorFast::get_biomes
	);


	ADD_PROPERTY(
		PropertyInfo(
			Variant::ARRAY,
			"biomes",
			PROPERTY_HINT_ARRAY_TYPE,
			"VoxelBiome"
		),
		"set_biomes",
		"get_biomes"
	);
}

} // namespace voxel
} // namespace zylann