Eden is a minimal framework built on SDL and written in Zig.

Eden is not a game engine, but it will aim to include some facilities similar to a game engine. It's primarily designed for graphics programming, tinkering, and experimenting.

Currently existing or planned components:
- 3D rendering to a window (SDL2, Vulkan)
- An extendable framework for simulating entities and their components
- A math library including 3D-related vector and matrix math; color types and 2D arrays with image processing functions; and random number generation utilities
- Some generic utilities for file management (AssImp, stbimage)
- Basic UI (Dear ImGui)

Currently compiling on windows 10 with zig-0.14.0.

The framework is currently pre-v0.1, but feel free to use it as a reference.

The project is likely to have temp code testing out new features during its development.

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
