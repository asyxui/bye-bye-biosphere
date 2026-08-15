# ByeByeBiosphere

[![Godot CI](https://github.com/asyxui/bye-bye-biosphere/actions/workflows/ci.yml/badge.svg)](https://github.com/asyxui/bye-bye-biosphere/actions/workflows/ci.yml)

## Building
This project uses a custom build of [Zylann's Godot Voxel](https://github.com/Zylann/godot_voxel).

Before compiling godot_voxel, clone the latest version of the [godot-cpp repository](https://github.com/godotengine/godot-cpp) into addons/godot_voxel/godot-cpp.

Both godot-cpp and godot_voxel need to be compiled with SCons. First, build godot-cpp, then build godot_voxel:

```
cd addons/godot_voxel/godot-cpp
scons platform=windows target=editor api_version=4.7
```

```
cd ..
scons platform=windows target=editor api_version=4.7
```

You may then copy the generated dll from /addons/godot_voxel/project/addons/zylann.voxel/bin to /addons/zylann.voxel/bin