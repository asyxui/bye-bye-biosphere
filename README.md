# ByeByeBiosphere

[![Godot CI](https://github.com/asyxui/bye-bye-biosphere/actions/workflows/ci.yml/badge.svg)](https://github.com/asyxui/bye-bye-biosphere/actions/workflows/ci.yml)

## Terrain generation

Terrain uses [godot_voxel](addons/godot_voxel), a GDExtension that must be compiled from source before running the project.

Terrain height and caves are generated separately, then a coastal seal blocks caves near sea level and leaves deep undersea caves enclosed by rock. Ocean voxels fill only open space between the seabed and the shared `Y=0` sea level; materials are assigned after terrain occupancy is resolved.

### Building godot_voxel

1. Clone the `godot-cpp` 4.5 branch into `addons/godot_voxel/godot-cpp`:

   ```
   git clone --branch 4.5 https://github.com/godotengine/godot-cpp addons/godot_voxel/godot-cpp
   ```

2. From the repository root, build `godot-cpp` and then the extension. The `4.5` branch supplies the GDExtension API bindings; `api_version=4.7` is not a recognized SCons option on this branch and is ignored, so it can be omitted. This older API is supported by Godot 4.7:

   ```
   cd addons/godot_voxel/godot-cpp
   scons platform=windows target=editor

   cd ..
   scons platform=windows target=editor
   scons platform=windows target=template_release
   ```

3. In PowerShell, from the `addons/godot_voxel` directory, return to the repository root and copy the compiled Windows binaries into the extension folder used by this project:

   ```
   cd ..\..
   Copy-Item -Path addons\godot_voxel\project\addons\zylann.voxel\bin\*.dll -Destination addons\zylann.voxel\bin\ -Force
   ```
