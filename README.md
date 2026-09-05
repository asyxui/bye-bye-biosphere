# ByeByeBiosphere

[![Godot CI](https://github.com/asyxui/bye-bye-biosphere/actions/workflows/ci.yml/badge.svg)](https://github.com/asyxui/bye-bye-biosphere/actions/workflows/ci.yml)

## Terrain generation

Terrain uses [godot_voxel](addons/godot_voxel), a GDExtension that must be compiled from source before running the project.

Terrain height and caves are generated separately, then a coastal seal blocks caves near sea level and leaves deep undersea caves enclosed by rock. Ocean voxels fill only open space between the seabed and the shared `Y=0` sea level; materials are assigned after terrain occupancy is resolved.

### Building godot_voxel

1. Clone the `godot-cpp` repository into `addons/godot_voxel/godot-cpp`, using the branch matching your Godot version (`4.5`):

   ```
   git clone --branch 4.5 https://github.com/godotengine/godot-cpp addons/godot_voxel/godot-cpp
   ```

2. Build `godot-cpp`, then build `godot_voxel` with SCons:

   ```
   cd addons/godot_voxel/godot-cpp
   scons platform=windows target=editor api_version=4.7

   cd ..
   scons platform=windows target=editor api_version=4.7
   ```

   Make sure the `godot-cpp` version is compatible with the version of Godot you are using.

3. Copy the compiled binaries into the extension folder Godot actually loads them from:

   ```
   copy from addons/godot_voxel/project/addons/zylann.voxel/bin
     to  addons/zylann.voxel/bin
   ```
