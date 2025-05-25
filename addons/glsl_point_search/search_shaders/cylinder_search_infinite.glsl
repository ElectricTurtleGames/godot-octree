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
    float radius;
    vec3 cyl_start;   // Start of the cylinder axis
    vec3 cyl_end;     // End of the cylinder axis
};

void main() {
    uint idx = gl_GlobalInvocationID.x;
    if (idx >= point_count) return;

    vec3 p = points[idx];
    vec3 a = cyl_start;
    vec3 b = cyl_end;
    vec3 ab = normalize(b - a); // direction of the infinite cylinder
    vec3 ap = p - a;

    // Project point onto cylinder axis
    float t = dot(ap, ab);
    vec3 proj = a + t * ab;

    // Distance from point to axis
    vec3 diff = p - proj;
    float dist_sq = dot(diff, diff);

    results[idx] = int(dist_sq <= radius * radius);
}