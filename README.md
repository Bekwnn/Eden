Eden is a minimal framework built on SDL2 and written in Zig.

It's not a game engine, but something very similar to one. It's primarily designed for graphics programming, tinkering, and experimenting.
Currently existing or planned components:
- 3D rendering to a window (SDL2, Vulkan)
- An extendable framework for simulating entities and their components
- A math library including 3D-related vector and matrix math; color types and 2D arrays with image processing functions; and random number generation utilities
- Some generic utilities for file management (AssImp, stbimage)
- Basic UI (Dear ImGui)

Currently compiling on windows with zig-0.9.0.

The framework is currently pre-v0.1, but feel free to use it as a reference.

The project is likely to have temp code testing out new features during its development.

Initial (one-time) setup:
* grab the dependency/cimgui submodule
* grab the dependency/cimgui/imgui submodule
* follow the README.md in dependency/cimgui-modified-impl and copy the modified .h/.cpp files
* run cmake on dependency/assimp and build the assimp project in RelWithDebInfo and Release modes

TODO: make build.zig do as much of this initial set up as possible; try to make setup a 1-step process

