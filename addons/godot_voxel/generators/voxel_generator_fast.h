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

	
	static constexpr float BLOCK_TYPE_FREQUENCY = 1.0f / 64.0f;
	static constexpr float TERRAIN_FREQUENCY = 1.0f / 80.0f;
	static constexpr float CAVE_FREQUENCY = 1.0f / 250.0f;
	static constexpr float BIOME_FREQUENCY = 1.0f / 30.0f;
	
	static constexpr float CAVE_CUTOFF = 0.3f;
	
	
	static constexpr int BLOCK_GREY = 1;
	static constexpr int BLOCK_PURPLE = 2;
	
	
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