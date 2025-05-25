extends Node
class_name PointSearch

static var _rendering_device: RenderingDevice

static var _sphere_search_shader_file: Resource = load("res://addons/glsl_point_search/search_shaders/sphere_search.glsl")
static var _sphere_search_shader: RID

static var _aabb_search_shader_file: Resource = load("res://addons/glsl_point_search/search_shaders/aabb_search.glsl")
static var _aabb_search_shader: RID

static var _finite_cylinder_search_shader_file: Resource = load("res://addons/glsl_point_search/search_shaders/cylinder_search.glsl")
static var _finite_cylinder_search_shader: RID

static var _infinite_cylinder_search_shader_file: Resource = load("res://addons/glsl_point_search/search_shaders/cylinder_search_infinite.glsl")
static var _infinite_cylinder_search_shader: RID

static var _shaders_compiled: bool = false

## A binary mask which can be applied to an array
class ArrayMask:
    var _bool_mask: Array
    var _int_mask: PackedInt32Array
    var _float_mask: PackedFloat32Array
    
    var mask: Variant:
        get: 
            match(mask_type):
                ArrayMaskType.BOOL: return _bool_mask
                ArrayMaskType.INT: return _int_mask
                ArrayMaskType.FLOAT: return _float_mask
            printerr("Mask has not yet been initialized; no mask exists")
            return null
    
    var mask_type: ArrayMaskType = ArrayMaskType.BOOL
    
    enum ArrayMaskType {
        INT,
        FLOAT,
        BOOL
    }
    
    func init(_mask: Variant):
        if _mask is Array and _mask.size() > 0 and _mask[0] is bool:
            mask_type = ArrayMaskType.BOOL
            _bool_mask = _mask
        elif _mask is PackedInt32Array and _mask.size() > 0:
            mask_type = ArrayMaskType.INT
            _int_mask = _mask
        elif _mask is PackedFloat32Array and _mask.size() > 0:
            mask_type = ArrayMaskType.FLOAT
            _float_mask = _mask
        else:
            printerr("Mask must have elements and be of the following types: 'PackedInt32Array, PackedFloat32Array, Array[bool]'")
    
    func _apply_int_to_array(array: Array[Variant]) -> Array[Variant]:
        if array.size() != _int_mask.size():
            printerr("Input array and mask array are not the same length.")
            assert(false)
            
        var result = []
        for i in range(array.size()):
            if _int_mask[i] == 1:
                result.append(array[i])
            
        return result
    
    func _apply_float_to_array(array: Array[Variant]) -> Array[Variant]:
        if array.size() != _float_mask.size():
            printerr("Input array and mask array are not the same length.")
            assert(false)
            
        var result = []
        for i in range(array.size()):
            if _float_mask[i] == 1.0:
                result.append(array[i])
            
        return result
            
    func _apply_bool_to_array(array: Array[Variant]) -> Array[Variant]:
        if array.size() != _bool_mask.size():
            printerr("Input array and mask array are not the same length.")
            assert(false)
            
        var result = []
        for i in range(array.size()):
            if _bool_mask[i]:
                result.append(array[i])
            
        return result
            
    func apply_to_array(array: Array) -> Array:
        # if they are not the same length, fail
        var _mask = mask
        
        # get all elements in input array where mask is true
        match(mask_type):
            ArrayMaskType.BOOL: return _apply_bool_to_array(array)
            ArrayMaskType.INT: return _apply_int_to_array(array)
            ArrayMaskType.FLOAT: return _apply_float_to_array(array)
            
        return []
        
    static func create_mask(array: Array, condition: Callable) -> ArrayMask:
        var mapped = array.map(condition)
        var new_mask = ArrayMask.new()
        new_mask.init(mapped)
        return new_mask
    
func _ready():
    _compile_search_shaders()
  
# SPHERE SEARCH

## Use a precompiled compute shader to find points within a sphere
## [param point_array] The array of points to query
## [param center] The center point of the sphere in which to search
## [param radius] The radius of the sphere in which to search
## [return] A mask of the array representing elements which were contained within the search area
static func sphere_search(point_array: Array, center: Vector3, radius: float) -> ArrayMask:
    if not _shaders_compiled:
        _compile_search_shaders()
    
    var mask = ArrayMask.new()
    var params = _build_sphere_params(point_array.size(), center, radius)
    var mask_array = _run_search(point_array, params, _sphere_search_shader)
    mask.init(mask_array)

    return mask
    
static func _build_sphere_params(point_count: int, center: Vector3, radius: float) -> PackedByteArray:    
    var radius_squared = radius ** 2.0
    # build the params byte array
    # includes padding values
    var params = PackedByteArray()
    params.resize(48)
    params.encode_u32(0, point_count)
    params.encode_float(16, center.x)
    params.encode_float(20, center.y)
    params.encode_float(24, center.z)
    params.encode_float(28, 0.0)  # padding to align vec3 to vec4
    params.encode_float(32, radius_squared)
    params.encode_u32(36, 0)  # padding to 8-byte alignment for uint
    params.encode_u32(40, 0)  # padding to 32-byte block
        
    return params
    
# AABB SEARCH

## Use a precompiled compute shader to find points within an aabb (3D rectangular prism)
## [param point_array] The array of points to query
## [param aabb] The AABB in which to search
## [return] A mask of the array representing elements which were contained within the search area
static func aabb_search(point_array: Array, aabb: AABB) -> ArrayMask:
    if not _shaders_compiled:
        _compile_search_shaders()
    
    var mask = ArrayMask.new()
    var params = _build_aabb_params(point_array.size(), aabb.position, aabb.end)
    var mask_array = _run_search(point_array, params, _aabb_search_shader)
    mask.init(mask_array)

    return mask
    
static func _build_aabb_params(point_count: int, aabb_start: Vector3, aabb_end: Vector3) -> PackedByteArray:
    # build the params byte array
    # includes padding values
    var params = PackedByteArray()
    params.resize(48)
    params.encode_u32(0, point_count)
    params.encode_float(16, aabb_start.x)
    params.encode_float(20, aabb_start.y)
    params.encode_float(24, aabb_start.z)
    params.encode_float(28, 0.0)  # padding to align vec3 to vec4
    params.encode_float(32, aabb_start.x)
    params.encode_float(36, aabb_start.y)
    params.encode_float(40, aabb_start.z)
    params.encode_float(44, 0.0)  # padding to align vec3 to vec4
        
    return params
    
# CYLINDER SEARCH

## Use a precompiled compute shader to find points within a cylinder
## [param point_array] The array of points to query
## [param start] The starting point of the cylinder in which to search
## [param end] The ending point of the cylinder in which to search
## [param radius] The radius of the cylinder in which to search
## [param extend_infinitely] If true, the cylinder will be extended infinitely along its axis.  
##      Otherwise it will only search between the start and end points.
## [return] A mask of the array representing elements which were contained within the search area
static func cylinder_search(point_array: Array, start: Vector3, end: Vector3, radius: float, extend_infinitely: bool = false) -> ArrayMask:
    if not _shaders_compiled:
        _compile_search_shaders()
    
    var mask = ArrayMask.new()
    var params = _build_cylinder_params(point_array.size(), start, end, radius)
    
    # call the appropriate shader based on whether or not infinite is desired
    var mask_array: PackedInt32Array
    if extend_infinitely:
        mask_array = _run_search(point_array, params, _infinite_cylinder_search_shader)
    else:
        mask_array = _run_search(point_array, params, _finite_cylinder_search_shader)
        
    mask.init(mask_array)

    return mask
    
static func _build_cylinder_params(point_count: int, start: Vector3, end: Vector3, radius: float) -> PackedByteArray:    
    var radius_squared = radius ** 2.0
    # build the params byte array
    # includes padding values
    var params = PackedByteArray()
    params.resize(48)
    params.encode_u32(0, point_count)
    params.encode_float(4, radius_squared)
    params.encode_float(16, start.x)
    params.encode_float(20, start.y)
    params.encode_float(24, start.z)
    params.encode_float(28, 0.0)  # padding to align vec3 to vec4
    params.encode_float(32, end.x)
    params.encode_float(36, end.y)
    params.encode_float(40, end.z)
    params.encode_float(44, 0.0)  # padding to align vec3 to vec4
        
    return params
    
# Generic Functions
    
static func _build_uniform_set(input_array: Array, params: PackedByteArray, shader: RID) -> Dictionary:   
    var input_value_bytes = 16
    var input_bytes := PackedByteArray()
    input_bytes.resize(input_value_bytes * input_array.size())
    for i in range(input_array.size()):
        var v = input_array[i]
        input_bytes.encode_float(i * input_value_bytes + 0, v.x)
        input_bytes.encode_float(i * input_value_bytes + 4, v.y)
        input_bytes.encode_float(i * input_value_bytes + 8, v.z)
        input_bytes.encode_float(i * input_value_bytes + 12, 0.0)  # padding
    
    # create an output array that has the same number of elements as the input array
    var output: PackedInt32Array = []
    output.resize(input_array.size())
    output.fill(0)
    var output_bytes := output.to_byte_array()
    
    # generate a buffer from the input byte array
    var input_buffer := _rendering_device.storage_buffer_create(input_bytes.size(), input_bytes)
    # generate a buffer from the output byte array
    var output_buffer := _rendering_device.storage_buffer_create(output_bytes.size(), output_bytes)
    # generate a buffer from the params byte array
    var params_buffer := _rendering_device.uniform_buffer_create(params.size(), params)
    
    # create a uniform variable to pass to the compute shader
    var input_array_uniform := RDUniform.new()
    input_array_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
    input_array_uniform.binding = 0
    # add the buffer to the uniform as data via its RID
    input_array_uniform.add_id(input_buffer)
    
    # create a uniform for the output array
    var output_array_uniform := RDUniform.new()
    output_array_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
    output_array_uniform.binding = 1
    # add the buffer to the uniform as data via its RID
    output_array_uniform.add_id(output_buffer)
    
    var params_uniform := RDUniform.new()
    params_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
    params_uniform.binding = 2
    # add the buffer to the uniform as data via its RID
    params_uniform.add_id(params_buffer)
    
    # build the uniform set to pass to the compute shader
    var uniforms_array = [input_array_uniform, output_array_uniform, params_uniform]
    var uniform_set := _rendering_device.uniform_set_create(uniforms_array, shader, 0)
    
    return {
        "uniform_set": uniform_set,
        "input_buffer": input_buffer,
        "output_buffer": output_buffer,
        "params_buffer": params_buffer
    }
    
static func _run_search(input_array: Array, params: PackedByteArray, shader: RID) -> PackedInt32Array:
    var buffer_data = _build_uniform_set(input_array, params, shader)
    _build_pipeline(buffer_data["uniform_set"], input_array.size(), shader)
    # submit the pipeline to the rendering device for running
    _rendering_device.submit()
    # resync results
    # TODO: This should be set to await completion
    _rendering_device.sync()
    
    var output_bytes = _rendering_device.buffer_get_data(buffer_data["output_buffer"])
    var output = output_bytes.to_int32_array()

    _rendering_device.free_rid(buffer_data["input_buffer"])
    _rendering_device.free_rid(buffer_data["output_buffer"])
    _rendering_device.free_rid(buffer_data["params_buffer"])

    return output
    
static func _build_pipeline(uniform_set: RID, total_elements: int, shader: RID):
    var pipeline := _rendering_device.compute_pipeline_create(shader)
    
    # start the compute list (instruction set)
    var compute_list := _rendering_device.compute_list_begin()
    # bind the pipeline and to the compute list
    _rendering_device.compute_list_bind_compute_pipeline(compute_list, pipeline)
    # bind the uniform set to the compute list
    _rendering_device.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
    # dispatch the compute list to the rendering device with the work group count
    var workgroup_size = 64  # must match local_size_x in shader
    var dispatch_size = int(ceil(float(total_elements) / workgroup_size))
    _rendering_device.compute_list_dispatch(compute_list, dispatch_size, 1, 1)
    # finish the compute list
    _rendering_device.compute_list_end()

static func _compile_search_shaders():
    _rendering_device = RenderingServer.create_local_rendering_device()
    
    var _sphere_shader_spirv = _sphere_search_shader_file.get_spirv()
    _sphere_search_shader = _rendering_device.shader_create_from_spirv(_sphere_shader_spirv)
    
    var _aabb_shader_spirv = _aabb_search_shader_file.get_spirv()
    _aabb_search_shader = _rendering_device.shader_create_from_spirv(_aabb_shader_spirv)
    
    var _finite_cylinder_shader_spirv = _finite_cylinder_search_shader_file.get_spirv()
    _finite_cylinder_search_shader = _rendering_device.shader_create_from_spirv(_finite_cylinder_shader_spirv)
    
    var _infinite_cylinder_shader_spirv = _infinite_cylinder_search_shader_file.get_spirv()
    _infinite_cylinder_search_shader = _rendering_device.shader_create_from_spirv(_infinite_cylinder_shader_spirv)
        
    _shaders_compiled = true
    
