#pragma once

#include "generators/voxel_generator.h"
#include "storage/voxel_buffer.h"
#include "voxel_biome.h"

#include "util/noise/fast_noise_lite/fast_noise_lite.h"

using namespace godot;


namespace zylann {
namespace voxel {


class VoxelGeneratorFast : public VoxelGenerator
{
	GDCLASS(VoxelGeneratorFast, VoxelGenerator)

private:

	Ref<ZN_FastNoiseLite> block_type_noise;
	Ref<ZN_FastNoiseLite> terrain_noise;
	Ref<ZN_FastNoiseLite> cave_noise;
	Ref<ZN_FastNoiseLite> biome_noise;

	
	float block_type_period = 64.0f;
	float terrain_period = 80.0f;
	float cave_period = 250.0f;
	float biome_period = 100.0f;
	
	float cave_cutoff = 0.3f;

	int block_type_seed = 0;
	int terrain_seed = 0;
	int cave_seed = 0;
	int biome_seed = 0;	
	
	static constexpr int BLOCK_GREY = 1;
	static constexpr int BLOCK_PURPLE = 2;
	
	void set_block_type_period(float value);
	float get_block_type_period() const;

	void set_terrain_period(float value);
	float get_terrain_period() const;

	void set_cave_period(float value);
	float get_cave_period() const;

	void set_biome_period(float value);
	float get_biome_period() const;

	void set_cave_cutoff(float value);
	float get_cave_cutoff() const;

	void set_block_type_seed(int value);
	int get_block_type_seed() const;

	void set_terrain_seed(int value);
	int get_terrain_seed() const;

	void set_cave_seed(int value);
	int get_cave_seed() const;

	void set_biome_seed(int value);
	int get_biome_seed() const;
	
	struct Biome
	{
		float base_height;
		float terrain_amplitude;
		float threshold_center;
	};
	
	Array biomes;

	Vector2 get_blended_biome(float x, float z) const;

	void prepare_noise();


protected:

	static void _bind_methods();


public:

	VoxelGeneratorFast();

	Result generate_block(VoxelQueryData input) override;

    int get_used_channels_mask() const override;

	Array get_biomes() const;
	void set_biomes(Array value);
};


} // namespace voxel
} // namespace zylann