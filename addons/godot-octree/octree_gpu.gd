#@icon("res://addons/godot-octree/octree_icon.svg")

extends Octree
class_name OctreeGPU

func _ready():
    super._ready()
    
    #_test()


func get_leaves_in_radius(center: Vector3, radius: float) -> Array[OctreeLeaf]:
    var result: Array[OctreeLeaf]
    var stack: Array[Octree] = [self]

    var potential_leaves: Array[OctreeLeaf] = []

    while stack.size() > 0:
        var node = stack.pop_back()
        if not aabb_intersects_sphere(node.bounding_box, center, radius):
            continue

        potential_leaves.append_array(node.leaves)

        for octave in node.octaves.values():
            stack.append(octave)
    
    var leaf_points = potential_leaves.map(func(leaf: OctreeLeaf): return leaf.leaf_position)
    var leaf_mask = PointSearch.sphere_search(leaf_points, center, radius)
    result.assign(leaf_mask.apply_to_array(potential_leaves))
    
    return result

func get_leaves_in_aabb(aabb: AABB) -> Array[OctreeLeaf]:
    var result: Array[OctreeLeaf]
    var stack: Array[Octree] = [self]

    var potential_leaves: Array[OctreeLeaf] = []

    while stack.size() > 0:
        var node = stack.pop_back()
        if not Octree.aabb_intersects_aabb(node.bounding_box, aabb):
            continue

        potential_leaves.append_array(node.leaves)

        for octave in node.octaves.values():
            stack.append(octave)
    
    var leaf_points = potential_leaves.map(func(leaf: OctreeLeaf): return leaf.leaf_position)
    var leaf_mask = PointSearch.aabb_search(leaf_points, aabb)
    result.assign(leaf_mask.apply_to_array(potential_leaves))
    
    return result

func get_leaves_in_cylinder(start: Vector3, end: Vector3, radius: float, extend_infinite: bool = false) -> Array[OctreeLeaf]:
    var result: Array[OctreeLeaf]
    var stack: Array[Octree] = [self]

    var potential_leaves: Array[OctreeLeaf] = []

    while stack.size() > 0:
        var node = stack.pop_back()        
        if extend_infinite and not aabb_intersects_cylinder_inf(node.bounding_box, start, end, radius):
            continue
        elif not aabb_intersects_cylinder(node.bounding_box, start, end, radius):
            continue

        potential_leaves.append_array(node.leaves)

        for octave in node.octaves.values():
            stack.append(octave)
    
    var leaf_points = potential_leaves.map(func(leaf: OctreeLeaf): return leaf.leaf_position)
    var leaf_mask = PointSearch.cylinder_search(leaf_points, start, end, radius, extend_infinite)
    result.assign(leaf_mask.apply_to_array(potential_leaves))
    
    return result
#
#func _test():
    #var center = Vector3(0.0, 0.0, 0.0)
    #var radius = 10.0
    #var radius_squared = radius ** 2.0
    #
    #var input = []
    #for i in range(1000):
        #input.append(Vector3(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0), randf_range(-10.0, 10.0)))
    #
    ##print(input)
    #
    #print("Input Params:")
    #print("Points: ", input.size())
    #print("Radius: ", radius)
    #print()
    #var start = Time.get_unix_time_from_system()
    #var mask = PointSearch.sphere_search(input, center, radius)
    #var results = mask.apply_to_array(input)
    #print("Compute: ", results.size())
    #print("Elapsed: ", Time.get_unix_time_from_system() - start)
    #print()
    #
    #start = Time.get_unix_time_from_system()
    #var result_classic = []
    #for point in input:
        #if center.distance_squared_to(point) <= radius_squared:
            #result_classic.append(point)
            #
    #print("Classic: ", result_classic.size())
    #print("Elapsed: ", Time.get_unix_time_from_system() - start)
    #print()
        #
    #start = Time.get_unix_time_from_system()
    #var result_hybrid = []
    #for point in input:
        #var diff: Vector3 = point - center
        #var dist_squared = diff.dot(diff)
        #if dist_squared <= radius_squared:
            #result_hybrid.append(point)
    #
    #print("Hybrid: ", result_hybrid.size())
    #print("Elapsed: ", Time.get_unix_time_from_system() - start)
    #print()
