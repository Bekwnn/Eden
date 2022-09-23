// So we need a notion of visual entities
// - visual entities can have a number of different elements:
//  + particles
//  + mesh
//  + animation
//  + shader
//  + textures
//  + etc
//  And one visual should be able to be a collection of these things

// Each shader, mesh, and texture needs to be loaded and passed to the gaphics api, so we need another notion of "assets"

// Assets and visuals should live in a fast, queryable database

// presentation should provide game with a simple api that lets game do, say,
// LoadMesh(filepath), LoadImage(filepath)
// It should also provide an api for creating and destroying presentation objects
// CreateMeshVisual(params), CreateParticleSystem(params), etc

// A mesh can have multiple textures or make use of multiple particle systems or have many animations, and so we need some way of building
// a complex visual object from these components. Game should be able to create, delete, and manipulate these objects pretty freely without
// having to get too "under the hood" of presentation-side's tasks of handling the graphics api.

// We need some notion of scenes/worlds and the ability to switch between them (the ability to do level streaming should have some consideration)

pub const VisualManager = struct { AutoHashMap };
