extends Node3D

@export_range(0.01, 8.0, 0.01, "suffix:(10^n)", "or_greater") var object_count: float = 3.0

@export var default_material: Material
@export var highlight_material: Material

@export var animate: bool = false
@export var animation_rate: float = 1.0

@export_range(0.01, 8.0, 0.01, "suffix:(10^n)", "or_greater") var init_update_interval: float = 3.0

@export var search_shape: SearchShape = SearchShape.SPHERE
@export var search_radius: float = 20.0

@export var cylinder_length: float = 10.0

@export_group("Nodes")
@export var octree: Octree
@export var camera_axis: Node3D
@export var total_trees_value: Label
@export var total_leaves_value: Label
@export var highlighted_leaves_value: Label
@export var fps_value: Label

var octree_size: Vector3

var n_objects: int:
    get: return int(10 ** object_count)
    
var init_update_rate: int:
    get: return int(10 ** init_update_interval)

var _animation_timer: float = 0.0
var _octree_generated: bool = false
var _sphere_mesh: SphereMesh

var _currently_highlighted: Array

enum SearchShape {
    SPHERE,
    CUBE,
    CYLINDER,
    CYLINDER_INF,
}

# Called when the node enters the scene tree for the first time.
func _ready():
    octree_size = octree.size
    _currently_highlighted = []
    await _generate()
    print(octree.total_trees)
    #_test_radius()
    
func _generate():
    _sphere_mesh = SphereMesh.new()
    _sphere_mesh.radius = 0.5
    _sphere_mesh.height = 1.0
    
    for i in range(n_objects):
        var pos = Vector3(randf_range(-octree_size.x/2.0, octree_size.x/2.0),
                        randf_range(-octree_size.y/2.0, octree_size.y/2.0),
                        randf_range(-octree_size.z/2.0, octree_size.z/2.0))
        var new_item = MeshInstance3D.new()
        new_item.mesh = _sphere_mesh
        new_item.set_surface_override_material(0, default_material)
        
        octree.add_leaf_item(new_item, pos)
        if i % init_update_rate == 0:
            print(i)
            await get_tree().create_timer(0.001).timeout
        
    _octree_generated = true
        
func _search_area():    
    for leaf in _currently_highlighted:
        leaf.leaf_item.set_surface_override_material(0, default_material)    
    
    _currently_highlighted.clear()
        
    var results = []
    match(search_shape):
        SearchShape.SPHERE:
            results = _search_sphere()
        SearchShape.CUBE:
            results = _search_cube()
        SearchShape.CYLINDER:
            results = _search_cylinder()
        SearchShape.CYLINDER_INF:
            results = _search_cylinder_inf()
        
    _currently_highlighted = results
    for obj in results:
        obj.leaf_item.set_surface_override_material(0, highlight_material)

func _search_sphere():
    var elapsed_time = Time.get_ticks_msec()
    var center = get_modulated_vector3(elapsed_time / 1000.0, octree_size/2.0 - Vector3.ONE * 10, Vector3(0.2, 0.4, 0.6))
    return octree.get_leaves_in_radius(center, search_radius)
    
func _search_cube():
    var elapsed_time = Time.get_ticks_msec()
    var center = get_modulated_vector3(elapsed_time / 1000.0, octree_size/2.0 - Vector3.ONE * 10, Vector3(0.2, 0.4, 0.6))
    var start = center + Vector3.ONE * (search_radius / 2.0)
    var size = Vector3.ONE * search_radius
    return octree.get_leaves_in_aabb(AABB(start, size))
    
func _search_cylinder():
    var elapsed_time = Time.get_ticks_msec()
    var center = get_modulated_vector3(elapsed_time / 1000.0, octree_size/2.0 - Vector3.ONE * 10, Vector3(0.2, 0.4, 0.6))
    var modulated_direction = get_modulated_vector3(elapsed_time / 1000.0, Vector3.ONE, Vector3(0.2, 0.4, 0.6)).normalized()
    var start = center - modulated_direction * (cylinder_length / 2.0)
    var end = center + modulated_direction * (cylinder_length / 2.0)
    return octree.get_leaves_in_cylinder(start, end, search_radius)
    
func _search_cylinder_inf():
    var elapsed_time = Time.get_ticks_msec()
    var center = get_modulated_vector3(elapsed_time / 1000.0, octree_size/2.0 - Vector3.ONE * 10, Vector3(0.2, 0.4, 0.6))
    var modulated_direction = get_modulated_vector3(elapsed_time / 1000.0, Vector3.ONE, Vector3(0.2, 0.4, 0.6)).normalized()
    var start = center - modulated_direction * (cylinder_length / 2.0)
    var end = center + modulated_direction * (cylinder_length / 2.0)
    return octree.get_leaves_in_cylinder(start, end, search_radius, true)
        
func _physics_process(delta):
    if animate:
        camera_axis.rotate_y(0.1 * delta)

        if _animation_timer <= 0 and _octree_generated:
            _search_area()
            _animation_timer = animation_rate
        _animation_timer -= delta
    
        _update_labels()
    
    #if animate and _animation_timer <= 0 and _octree_generated:
        #var center = Vector3(randf_range(-octree_size.x/2.0, octree_size.x/2.0),
                        #randf_range(-octree_size.y/2.0, octree_size.y/2.0),
                        #randf_range(-octree_size.z/2.0, octree_size.z/2.0))
        #for obj in octree.get_leaves_in_radius(center, randf_range(1, 100)):
            #obj.leaf_item.set_
        #_animation_timer = animation_rate
        
func _update_labels():
    total_trees_value.text = "%d" % octree.total_trees
    total_leaves_value.text = "%d" % octree.total_leaves
    highlighted_leaves_value.text = "%d" % _currently_highlighted.size()
    fps_value.text = "%d" % Engine.get_frames_per_second()
        
func get_modulated_vector3(time: float, amplitude: Vector3, frequency: Vector3) -> Vector3:
    var x = sin(time * frequency.x) * amplitude.x
    var y = sin(time * frequency.y) * amplitude.y
    var z = sin(time * frequency.z) * amplitude.z
    return Vector3(x, y, z)
