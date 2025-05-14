# Godot Octree
Extendable 3D Octrees for `Godot 4.x`

![An example of the demo project running with 100,000 leaves](https://github.com/ElectricTurtleGames/godot-octree/blob/main/addons/godot-octree/example/example.gif)

## Octrees
An octree is a data structure commonly used for representing a large number of objects in 3D space in an extremely efficient manner.  This is accomplished by splitting an area of 3D space into recursive "octants", or "octaves", which are themselves octrees.  Each octree has eight octaves, which can each be represented by Vector3i indices that define its direction from the center of the octree.  

Objects within the octree are "leaves", and are owned by the appropriate octave of the lowest depth.

Due to this recurvive tree structure, indexing and comparison on leaf locations is very effecient, and can greatly increase the performance of large object fields in Godot.

For an in-depth explanation of Octrees, see https://en.wikipedia.org/wiki/Octree#

## Implementation
This implementation of octree is designed specifically to work within the Godot 3D environment.  Octrees are all `Area3D`s with a `BoxShape3D` shape.  The generation of the collision shapes can be disabled if they are not wanted.
Octree Leaves are each `Node3D`s, and are designed to be extended as desired.  Alternatively, an `OctreeLeafContainer` node, which is itself an extension of `OctreeLeaf`, is provided that acts as a simple container for any item.

Each octree contains a `Dictionary` of octaves keyed by `Vector3i` octave indices, and is assigned a branch depth based on what depth of branch recursion that octree rests at in the overall tree.  Octaves will not be generated until
a leaf is added which is within that octave.  Leaves at the lowest depth of octave are stored in simple arrays.  Because of this, a higher maximum branch depth can increase search efficiency at the cost of more octaves and therefore a larger data structure.

###### Note: If your implementation of Octree contains many resource-dependant nodes, for instance a large number of `MeshInstance3D`s or `PhysicsShape3D`s, execution can be extremely slow due to repeated GPU draw commands or physics calculations.  To avoid this, it is recommend that you limit the number of unique Meshes or Shapes, either by using premade resources or by generating a resource pool.

## Usage
To use the `Octree` class, simply add an `Octree` node to your 3D scene, set the size of the octree's field, and it will be initialized on `_ready()`.  You can also extend `Octree` to create a custom tree.
The octree will be automatically segmented into octaves based on the defined size and desired maximum branch depth.

To add a node to the octree as a leaf, either extend the `OctreeLeaf` class and call `add_leaf()` on the `Octree`, or call `add_leaf_item()` with any `Node` to create an `OctaveLeafContainer` that contains that node.  Both functions
will add the new leaf to the appropriate octave based on its position, creating any octaves until the maximum depth has been reached.

To search for leaves efficiently within an octree, call `Octree.get_leaves_in_radius()` with the centerpoint and radius of a search sphere.  This operation will run in near-to `O(m)`, where `m` is the depth of the tree.  However, the 
lower octaves still contain arrays of objects that will be searched in `O(n)` time, so a higher branch depth will allow for much more efficient searches, at the cost of a larger data structure.

For more information on usage, see the inline documentation.

## Planned Features
- **Sector recalculation**: Monitoring of leaves to determine when a leaf has exited an octave, and subsequent re-assignment of that leaf to the new octave
- **Complex searching**: Ability to search the octree space for leaves using more than just a sphere
- **Hashed searching**: Storage of leaves using hashed metadata to allow for quicker conditional searches
- **Custom searching**: Ability to pass a callable to the search function which will act as a conditional statement
