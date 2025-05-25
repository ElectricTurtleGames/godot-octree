#[compute]
#version 450

layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

// Input: Array of Vector3 points
layout(set = 0, binding = 0, std430) readonly buffer Points {
    vec3 points[];
};

// Output: 0 or 1 for each point
layout(set = 0, binding = 1, std430) writeonly buffer Results {
    int results[];
};

// Uniforms must be in a block for Vulkan GLSL
layout(set = 0, binding = 2) uniform Params {
    uint point_count;
    vec3 aabb_start; // Min corner of the box
    vec3 aabb_end;   // Max corner of the box
};

void main() {
    uint idx = gl_GlobalInvocationID.x;
    if (idx >= point_count) return;

    vec3 p = points[idx];

    // Check if point is inside AABB
    bool inside = all(greaterThanEqual(p, aabb_start)) &&
                  all(lessThanEqual(p, aabb_end));

    results[idx] = int(inside);
}
