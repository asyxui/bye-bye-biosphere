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
					world_x / biome_period,
					world_z / biome_period
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

				if (cave_noise->get_noise_3d(world_x, world_y, world_z) >= cave_cutoff) continue;

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

	block_type_noise->set_seed(block_type_seed);
	block_type_noise->set_period(block_type_period);



	terrain_noise->set_noise_type(
		ZN_FastNoiseLite::TYPE_VALUE_CUBIC
	);

	terrain_noise->set_seed(terrain_seed);
	terrain_noise->set_period(terrain_period);

	terrain_noise->set_fractal_type(
		ZN_FastNoiseLite::FRACTAL_FBM
	);

	terrain_noise->set_fractal_octaves(2);
	terrain_noise->set_fractal_lacunarity(2.0f);
	terrain_noise->set_fractal_gain(0.5f);



	cave_noise->set_noise_type(
		ZN_FastNoiseLite::TYPE_OPEN_SIMPLEX_2
	);

	cave_noise->set_seed(cave_seed);
	cave_noise->set_period(cave_period);

	cave_noise->set_fractal_type(
		ZN_FastNoiseLite::FRACTAL_FBM
	);

	cave_noise->set_fractal_octaves(1);
	cave_noise->set_fractal_lacunarity(2.0f);
	cave_noise->set_fractal_gain(0.5f);



	biome_noise->set_noise_type(
		ZN_FastNoiseLite::TYPE_OPEN_SIMPLEX_2
	);

	biome_noise->set_seed(biome_seed);
	biome_noise->set_period(biome_period);
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

void VoxelGeneratorFast::set_block_type_period(float value)
{
	block_type_period = value;

	if (block_type_noise.is_valid())
		block_type_noise->set_period(value);
}

float VoxelGeneratorFast::get_block_type_period() const
{
	return block_type_period;
}


void VoxelGeneratorFast::set_terrain_period(float value)
{
	terrain_period = value;

	if (terrain_noise.is_valid())
		terrain_noise->set_period(value);
}

float VoxelGeneratorFast::get_terrain_period() const
{
	return terrain_period;
}


void VoxelGeneratorFast::set_cave_period(float value)
{
	cave_period = value;

	if (cave_noise.is_valid())
		cave_noise->set_period(value);
}

float VoxelGeneratorFast::get_cave_period() const
{
	return cave_period;
}


void VoxelGeneratorFast::set_biome_period(float value)
{
	biome_period = value;

	if (biome_noise.is_valid())
		biome_noise->set_period(value);
}

float VoxelGeneratorFast::get_biome_period() const
{
	return biome_period;
}

float VoxelGeneratorFast::get_cave_cutoff() const
{
	return cave_cutoff;
}


void VoxelGeneratorFast::set_cave_cutoff(float value)
{
	cave_cutoff = value;
}

void VoxelGeneratorFast::set_block_type_seed(int value)
{
	block_type_seed = value;

	if (block_type_noise.is_valid())
		block_type_noise->set_seed(value);
}

int VoxelGeneratorFast::get_block_type_seed() const
{
	return block_type_seed;
}

void VoxelGeneratorFast::set_terrain_seed(int value)
{
	terrain_seed = value;

	if (terrain_noise.is_valid())
		terrain_noise->set_seed(value);
}

int VoxelGeneratorFast::get_terrain_seed() const
{
	return terrain_seed;
}

void VoxelGeneratorFast::set_cave_seed(int value)
{
	cave_seed = value;

	if (cave_noise.is_valid())
		cave_noise->set_seed(value);
}

int VoxelGeneratorFast::get_cave_seed() const
{
	return cave_seed;
}

void VoxelGeneratorFast::set_biome_seed(int value)
{
	biome_seed = value;

	if (biome_noise.is_valid())
		biome_noise->set_seed(value);
}

int VoxelGeneratorFast::get_biome_seed() const
{
	return biome_seed;
}

String VoxelGeneratorFast::get_biome_at(Vector3 world_position) const
{
	const float x = world_position.x / biome_period;
	const float z = world_position.z / biome_period;

	const float t =
		(biome_noise->get_noise_2d(x, z) + 1.0f) * 0.5f;

	Ref<VoxelBiome> primary_biome;
	Ref<VoxelBiome> secondary_biome;

	float primary_weight = -1000.0f;
	float secondary_weight = -1000.0f;

	for (Variant v : biomes)
	{
		Ref<VoxelBiome> biome = v;

		if (biome.is_null())
			continue;

		const float dist =
			Math::abs(t - biome->get_threshold_center());

		const float weight =
			1.0f / Math::pow(dist + 0.001f, 2.0f);

		if (weight > primary_weight)
		{
			secondary_weight = primary_weight;
			secondary_biome = primary_biome;

			primary_weight = weight;
			primary_biome = biome;
		}
		else if (weight > secondary_weight)
		{
			secondary_weight = weight;
			secondary_biome = biome;
		}
	}

	if (primary_biome.is_null())
		return "None";

	if (secondary_biome.is_null())
		return primary_biome->get_biome_name() + " (100%)";

	const float total_weight =
		primary_weight + secondary_weight;

	const float primary_percentage =
		primary_weight / total_weight * 100.0f;

	const float secondary_percentage =
		secondary_weight / total_weight * 100.0f;

	return vformat(
		"%s (%.1f%%), %s (%.1f%%), threshold: %f",
		primary_biome->get_biome_name(),
		primary_percentage,
		secondary_biome->get_biome_name(),
		secondary_percentage,
		t
	);
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

	ClassDB::bind_method(
	D_METHOD("set_block_type_period", "value"),
	&VoxelGeneratorFast::set_block_type_period
	);

	ClassDB::bind_method(
		D_METHOD("get_block_type_period"),
		&VoxelGeneratorFast::get_block_type_period
	);

	ClassDB::bind_method(
		D_METHOD("set_terrain_period", "value"),
		&VoxelGeneratorFast::set_terrain_period
	);

	ClassDB::bind_method(
		D_METHOD("get_terrain_period"),
		&VoxelGeneratorFast::get_terrain_period
	);

	ClassDB::bind_method(
		D_METHOD("set_cave_period", "value"),
		&VoxelGeneratorFast::set_cave_period
	);

	ClassDB::bind_method(
		D_METHOD("get_cave_period"),
		&VoxelGeneratorFast::get_cave_period
	);

	ClassDB::bind_method(
		D_METHOD("set_biome_period", "value"),
		&VoxelGeneratorFast::set_biome_period
	);

	ClassDB::bind_method(
		D_METHOD("get_biome_period"),
		&VoxelGeneratorFast::get_biome_period
	);

	ClassDB::bind_method(
		D_METHOD("set_cave_cutoff", "value"),
		&VoxelGeneratorFast::set_cave_cutoff
	);

	ClassDB::bind_method(
		D_METHOD("get_cave_cutoff"),
		&VoxelGeneratorFast::get_cave_cutoff
	);

	ClassDB::bind_method(
		D_METHOD("get_biome_at", "world_position"),
		&VoxelGeneratorFast::get_biome_at
	);

	ClassDB::bind_method(D_METHOD("set_block_type_seed", "value"), &VoxelGeneratorFast::set_block_type_seed);
	ClassDB::bind_method(D_METHOD("get_block_type_seed"), &VoxelGeneratorFast::get_block_type_seed);

	ClassDB::bind_method(D_METHOD("set_terrain_seed", "value"), &VoxelGeneratorFast::set_terrain_seed);
	ClassDB::bind_method(D_METHOD("get_terrain_seed"), &VoxelGeneratorFast::get_terrain_seed);

	ClassDB::bind_method(D_METHOD("set_cave_seed", "value"), &VoxelGeneratorFast::set_cave_seed);
	ClassDB::bind_method(D_METHOD("get_cave_seed"), &VoxelGeneratorFast::get_cave_seed);

	ClassDB::bind_method(D_METHOD("set_biome_seed", "value"), &VoxelGeneratorFast::set_biome_seed);
	ClassDB::bind_method(D_METHOD("get_biome_seed"), &VoxelGeneratorFast::get_biome_seed);

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

	ADD_GROUP("Noise Parameters", "noise_");

	ADD_PROPERTY(
		PropertyInfo(Variant::INT, "noise_block_type_seed"),
		"set_block_type_seed",
		"get_block_type_seed"
	);

	ADD_PROPERTY(
		PropertyInfo(Variant::FLOAT, "noise_block_type_period",
			PROPERTY_HINT_RANGE, "1.0,500.0,1.0"),
		"set_block_type_period",
		"get_block_type_period"
	);

	ADD_PROPERTY(
		PropertyInfo(Variant::INT, "noise_terrain_seed"),
		"set_terrain_seed",
		"get_terrain_seed"
	);

	ADD_PROPERTY(
		PropertyInfo(Variant::FLOAT, "noise_terrain_period",
			PROPERTY_HINT_RANGE, "1.0,500.0,1.0"),
		"set_terrain_period",
		"get_terrain_period"
	);

	ADD_PROPERTY(
		PropertyInfo(Variant::INT, "noise_cave_seed"),
		"set_cave_seed",
		"get_cave_seed"
	);

	ADD_PROPERTY(
		PropertyInfo(Variant::FLOAT, "noise_cave_period",
			PROPERTY_HINT_RANGE, "1.0,1000.0,1.0"),
		"set_cave_period",
		"get_cave_period"
	);

	ADD_PROPERTY(
		PropertyInfo(Variant::INT, "noise_biome_seed"),
		"set_biome_seed",
		"get_biome_seed"
	);

	ADD_PROPERTY(
		PropertyInfo(Variant::FLOAT, "noise_biome_period",
			PROPERTY_HINT_RANGE, "1.0,500.0,1.0"),
		"set_biome_period",
		"get_biome_period"
	);

	ADD_PROPERTY(
		PropertyInfo(
			Variant::FLOAT,
			"noise_cave_cutoff",
			PROPERTY_HINT_RANGE,
			"0.01,1.0,0.01"
		),
		"set_cave_cutoff",
		"get_cave_cutoff"
	);

	
}

} // namespace voxel
} // namespace zylann