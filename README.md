Eden is a minimal framework built on SDL and written in Zig.

Eden is a general purpose engine for low level real-time simulations. It's primarily designed for writing performance-sensitive graphics/simulation experiments, but could also be used for games.

Currently compiling on windows 10 with zig-0.15.2.

The framework is currently pre-v0.1, but feel free to use it as a reference.

Currently existing or planned components:
- 3D rendering to a window (SDL2, Vulkan)
- An editor interface (Dear ImGui)
- An extendable ECS framework for simulating entities
- A math library including:
  + 3D-related vector and matrix math
  + several color data formats and conversion between them
  + 2D arrays with image processing functions
  + random generation utilities
- Some utilities for file management, asset loading (AssImp, stbimage)
- Ability to save and load scenes

The project is likely to have temp code testing out new features during its development. Once it's further along in development, it may have some stable branches.

Initial (one-time) setup:
* grab the `dependency/cimgui` and `dependency/cimgui/imgui` submodules
* run cmake on dependency/assimp and build the assimp project in RelWithDebInfo and Release modes
* place the built assimp dll file in `dependency/assimp/lib` and verify the dll's filename matches the file name used in `build.zig`

An end goal will be to minimize these steps either by using build.zig to do as much of this initial set up as possible automatically, or to restructure the project such that less setup is needed.

Usage:

`presentation/` contains all rendering and render loop related facilities. Also UI/Editor functions but that's likely to get its own directory soon.
`math/` contains an incomplete custom math library providing vector math and colors (and much more in the future)
`game/` contains an ECS architecture for simulations or games - currently just a prototype but should be hooked up to the presentation layer at some point
`coreutil/` provides additional std-like functions and general purpose utility

*"Why your own math library?"* I dislike the API of far too many math libraries I've used. But mostly as a personal learning exercise + I want to include a lot of custom functionality and utils (2d arrays w/ kernal operations, proc gen features, etc) that would require me to frankenstein math libs together or otherwise implement a good chunk of functionality myself anyways.

Once the math Library is sufficiently developed, it may separate into its own project.
