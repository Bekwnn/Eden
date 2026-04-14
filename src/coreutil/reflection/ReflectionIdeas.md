Writing with no internet on a ferry with plans to read/research further.

# Necessary?
There's a few benefits reasons to do some kind of reflection, even though Zig's comptime type info is quite strong:

1. Editor Reflection
2. Save/Load Reflection
3. Netcode Reflection

For 1., it would make sense that we want to control how fields and types are exposed to the editor in a simple way where types are concerned for their own editor implmentation instead of the editor being concerned with every type's editor implementation.

For 2., games need save load and while we could just mass serialize to JSON, that would be horrible for perf and filesizes. We want to specify which fields are saved and loaded or not. Also tools should have save load for preferences, settings, etc.

For 3., to have a networked game data will have to be transfered across the network and used to synchronize state. Any kind of netcode is a pretty big stretch for this engine at the moment, but it would be good if it remained a possiblity.

# Syntax

First thought:
```
Refl(MyType, .Options{ etc });
```

`Options` could contain things like `SaveLoadLevel`, `SaveLoadGame`, `ServerOnly`, etc. Whatever flavor of keywords are needed to specify which features should exist. 

`Options` could also contain a substruct `EditorOptions` which controls how the reflected type appears in the editor: read, readwrite, etc. If there aren't many options maybe don't make a substruct.

# Default reflection?

If reflection has some `.Options{}` struct specifying what type of reflection exists, for usability there should probably be some default options, or a few different pre-built structs.

# Implementation

Is there a way to duplicate `MyType` inside the reflection struct via field/function parsing?

Ideally there is minimal syntactical friction when dealing with `MyType` vs. `Refl(MyType)`. Having to type `myPos.data.x` instead of just `myPos.x` is less than ideal. If there is a way to instead just append reflection data:

--
MyType.field1
MyType.field2
MyType.field3
--
reflInfo
--
etc.

Then there's the question of how to use it with existing functions. We also want a `someFn(v1: Vec3, v2: Vec3) void { ... }` to be able to smoothly take either a Refl(Vec3) or a regular Vec3 or some combination of the two.
