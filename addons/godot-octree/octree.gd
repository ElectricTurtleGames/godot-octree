extends Area3D
class_name Octree

## The maximum branch depth of this octree.  The origin branch is depth 0
@export var max_depth: int = 1
## The size of this branch in 3D
@export var size: Vector3
@export var create_collider: bool

## The branch depth of this tree
var depth = 0
## An 8-element dictionary of octaves keyed by octave index
## {Vector3i, Octree}
var octaves: Dictionary
## The AABB bounding box of the tree.  The center of bounding box is at the tree global position
var bounding_box: AABB
## An array of leaves directly owned by this tree
var leaves: Array[OctreeLeaf]
## The total number of leaves contained within this tree and its branches
var total_leaves: int = 0

# DIRECTIONS
static var TOP_FRONT_RIGHT =       Vector3i( 1,  1,  1)
static var TOP_FRONT_LEFT =        Vector3i(-1,  1,  1)
static var TOP_BACK_RIGHT =        Vector3i( 1,  1, -1)
static var TOP_BACK_LEFT =         Vector3i(-1,  1, -1)
static var BOTTOM_FRONT_RIGHT =    Vector3i( 1, -1,  1)
static var BOTTOM_FRONT_LEFT =     Vector3i(-1, -1,  1)
static var BOTTOM_BACK_RIGHT =     Vector3i( 1, -1, -1)
static var BOTTOM_BACK_LEFT =      Vector3i(-1, -1, -1)

func _ready():
    bounding_box = AABB(global_position - size/2.0, size)
    leaves = []
    if create_collider:
        var collider = CollisionShape3D.new()
        collider.shape = BoxShape3D.new()
        collider.shape.size = bounding_box.size
        collider.position - bounding_box.position
        add_child(collider)
    
## Returns a list of all leaves contained within the provided sphere
## [param center] The center of the selection sphere
## [param radius] the radius of the selection sphere
func get_leaves_in_radius(center: Vector3, radius: float, condition: Callable = _default_get_radius_condition) -> Array[OctreeLeaf]:
    var contained_leaves: Array[OctreeLeaf] = []
    # if this octree intersects the radius, calculate whether leaves are in it
    if aabb_intersects_sphere(bounding_box, center, radius):
        # determine whether directly owned leaves are within the radius
        for leaf in leaves:
            #var pass_cond = condition.call(leaf)
            if leaf.global_position.distance_to(center) <= radius:# and pass_cond:
                contained_leaves.append(leaf)
        # get leaves within radius from child octaves
        for octave in octaves.values():
            contained_leaves.append_array(octave.get_leaves_in_radius(center, radius, condition))
    
    return contained_leaves
   
func _default_get_radius_condition(leaf: OctreeLeaf) -> bool:
    return true

## Removes a leaf from the octree, and removes empty octaves
## [param leaf] The leaf to be removed
## [param force_removal] Remove even if the leaf is no longer within the tree bounds
## [return] True if the leaf could be removed; false if not
func remove_leaf(leaf: OctreeLeaf, force_removal: bool = false) -> bool:
    # if the leaf is not within the bounds, it 
    if force_removal or contained(leaf.global_position):
        # check whether this leaf is directly owned by this tree, and remove it if so
        for owned_leaf in leaves:
            if owned_leaf == leaf:
                _remove_leaf_from_array(leaf)
                return true
        
        # attempt to remove the leaf from any child octaves
        var removed_successfully: bool = false
        for octave in octaves.values():
            if not removed_successfully:
                removed_successfully = octave.remove_leaf(leaf, force_removal)
        # if it was removed, reduce the total leaf count
        if removed_successfully:
            total_leaves -= 1
        return removed_successfully
    return false
 
## Adds a leaf to the octree; creates octaves as needed
## [param leaf] The leaf to add to the tree
## [return] True if the leaf could be added; false if not
func add_leaf(leaf: OctreeLeaf) -> bool:
    var leaf_position = leaf.leaf_position
    
    # if the leaf does not belong in this tree, it will not be added.
    if contained(leaf_position):
        var octave_index = get_octave_index(leaf_position)
        # if the octave exists, add the leaf to it
        if octaves.has(octave_index):
            # if the leaf was added successfully, increase the leaf count
            if octaves[octave_index].add_leaf(leaf):
                total_leaves += 1
                return true
            else:
                return false
        # if the octave doesn't exist, and is allowed to be created, create it and add the leaf
        elif depth < max_depth:
            # if the leaf was added successfully, increase the leaf count
            var new_octave = create_octave(octave_index)
            if new_octave.add_leaf(leaf):
                total_leaves += 1
                return true
            else:
                return false
        # otherwise, just add the leaf to this octree
        else:
            _add_leaf_to_array(leaf)
            return true

    printerr("Leaf is not positioned inside this tree's bounds.")
    return false

## Adds an item to a leaf that is contained within a leaf container
## [param item] The item that will be contained in the leaf container
## [return] True if the leaf could be added; false if not
func add_leaf_item(item: Node, leaf_position: Vector3) -> bool:
    var new_leaf = OctreeLeafContainer.new()
    new_leaf.leaf_position = leaf_position
    new_leaf.set_item(item)
    return add_leaf(new_leaf)

## Returns true if the provided point is contained within this tree's bounding box
## [param point] The point to check if its contained
## [return] True if the point is within the bounding box
func contained(point: Vector3) -> bool:
    return bounding_box.has_point(point)

## Gets the Vector3i index of the octave the given point falls in
## [param point] The point to find the octave id of
## [return] The Vector3i index that the point falls in
func get_octave_index(point: Vector3) -> Vector3i:
    var ix = (point.x - global_position.x) / (bounding_box.size.x / 2.0)
    var iy = (point.y - global_position.y) / (bounding_box.size.y / 2.0)
    var iz = (point.z - global_position.z) / (bounding_box.size.z / 2.0)
    
    var cx = truncate_away_from_zero(ix)
    var cy = truncate_away_from_zero(iy)
    var cz = truncate_away_from_zero(iz)
    return Vector3i(cx, cy, cz)

## Gets the octave in which a point falls
## [param point] The point to find the octave of    
## [return] The octave which owns the provided point
func get_octave(point: Vector3) -> Octree:
    var octave_index = get_octave_index(point)
    if octaves.has(octave_index):
        return octaves[octave_index]
    return null
    
## Recursively gets lowest rank octave that owns the given point
## [param point] The point to find the octave of    
## [return] The lowest octave which owns the provided point
func get_lowest_octave(point: Vector3) -> Octree:
    var octave_index = get_octave_index(point)
    if octaves.has(octave_index):
        return octaves[octave_index].get_octave_index()
    return self

## Adds a leaf directly to this tree, adding it as a child and increasing the leaf count
## [param leaf] The leaf to add to the tree
func _add_leaf_to_array(leaf: OctreeLeaf):
    leaf.parent_tree = self
    leaves.append(leaf)
    add_child(leaf)
    leaf.global_position = leaf.leaf_position
    total_leaves += 1

## Removes a leaf directly from this tree, removing it as a child and decreasing the leaf count
## [param leaf] The leaf to remove from this tree
func _remove_leaf_from_array(leaf: OctreeLeaf):
    leaf.parent_tree = null
    leaves.erase(leaf)
    remove_child(leaf)
    total_leaves -= 1

## Creates a new octave and adds it as a child
## [param index] The octave index of the new octave to add
## [return] The newly created octave
func create_octave(index: Vector3i) -> Octree:
    var new_octave = Octree.new()
    new_octave.name = "Octave (%d, %d, %d)" % [index.x, index.y, index.z]    
    new_octave.size = bounding_box.size / 2.0
    new_octave.max_depth = max_depth
    new_octave.depth = depth + 1
    new_octave.create_collider = create_collider
    octaves[index] = new_octave
    new_octave.position = (new_octave.size/2.0) * Vector3(index)
    add_child(new_octave)
    return new_octave
    
## Checks whether an AABB 3D bounding box intersects with a sphere
## [param aabb] The AABB to check for intersection with
## [param sphere_center] The center point of the sphere to check intersection with
## [param sphere_radius] The radius of the sphere to check intersection with
## [return] True if there is an intersection between the provided AABB and Sphere
static func aabb_intersects_sphere(aabb: AABB, sphere_center: Vector3, sphere_radius: float) -> bool:
    var closest_point = Vector3(
        clamp(sphere_center.x, aabb.position.x, aabb.position.x + aabb.size.x),
        clamp(sphere_center.y, aabb.position.y, aabb.position.y + aabb.size.y),
        clamp(sphere_center.z, aabb.position.z, aabb.position.z + aabb.size.z)
    )
    
    var distance_squared = closest_point.distance_squared_to(sphere_center)
    return distance_squared <= sphere_radius * sphere_radius

static func truncate_away_from_zero(value: float) -> int:
    var truncated = int(value)
    if value == truncated:
        return truncated
    return truncated + sign(value)
