Eden is a minimal game framework built on SDL2 and written in Zig.
Currently compiling with windows zig-0.9.0.

The framework is currently pre-v0.1, but feel free to use it as a reference.

Initial (one-time) setup:
* grab the dependency/cimgui submodule
* grab the dependency/cimgui/imgui submodule
* follow the README.md in dependency/cimgui-modified-impl and copy the modified .h/.cpp files
* run cmake on dependency/assimp and build the assimp project in RelWithDebInfo and Release modes

TODO: make build.zig do as much of this initial set up as possible; try to make setup a 1-step process

The project is likely to have temp code testing out new features during its development.
