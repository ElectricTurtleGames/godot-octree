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
    vec3 center;
    float _pad1;
    float radius_squared;
    uint _pad2;
    uint _pad3;
};

void main() {
    uint idx = gl_GlobalInvocationID.x;
    if (idx >= point_count) return;
    
    vec3 diff = points[idx].xyz - center;
    float dist_sq = dot(diff, diff);  // length squared

    // results[idx] = radius_squared;
    // //points[idx][1];

    results[idx] = int(dist_sq <= radius_squared);
}

