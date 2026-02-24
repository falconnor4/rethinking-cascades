#version 430

#define SHADOWCOMP
#define VOXEL_RADIANCE_CASCADE

#include "/shaders/lib/vx/voxelSettings.glsl"

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

#include "/shaders/lib/vx/voxelMapping.glsl"
#include "/shaders/lib/vx/SSBOs.glsl"
#include "/shaders/lib/vx/radianceCascades.glsl"

#include "/shaders/lib/common.glsl"

uniform float uWetness;
uniform float uTime;
uniform int uFrame;

const float PI = 3.14159265359;

float GetSunVisibility(vec3 p, vec3 d) {
    vec3 sp = p + d * 0.5;
    vec3 smPos = sp - (sunPosition + sunDirection * SUN_DIST);
    vec2 smUV = vec2(dot(smPos, sunTan), dot(smPos, sunBit)) / SUN_SIZE_SM / ASPECT_RCP * 0.5 + 0.5;
    return texture(uShadow, smUV).r > dot(smPos, -sunDirection) ? 1.0 : 0.0;
}

vec3 GetSkyLight(vec3 d) {
    float horizon = pow(max(0.0, 1.0 - abs(d.y)), 4.0);
    vec3 skyCol = horizon * ATMOSPHERE_AO_THICK_AIR_Color.rgb * 1.5;
    skyCol += AMBIENT.yzw * 0.02;
    return skyCol;
}

vec3 GetSunLight() {
    return SUNLIGHT_COLOR * 2.0;
}

bool TraceRay(vec3 p, vec3 d, out float t, out vec3 hitPos, out uvec4 voxel) {
    t = 0.0;
    vec3 idir = 1.0 / d;
    vec3 bmin = (voxelMin - p) * idir;
    vec3 bmax = (voxelMax - p) * idir;
    vec3 tmin = min(bmin, bmax);
    vec3 tmax = max(bmin, bmax);
    float t0 = max(max(tmin.x, tmin.y), tmin.z);
    float t1 = min(min(tmax.x, tmax.y), tmax.z);
    if (t0 > t1 || t1 < 0.0) return false;
    t = max(t0, 0.0);
    for (int i = 0; i < 128; i++) {
        hitPos = p + d * t;
        if (t > t1) break;
        ivec3 iv = ivec3(floor(hitPos));
        if (!IsInVolume(iv)) return false;
        uvec4 v = GetVoxel(iv);
        if (v.w > 0) {
            voxel = v;
            return true;
        }
        vec3 nextPlane = (float(sign(d)) * 0.5 + 0.5 + vec3(d) * idir) + floor(hitPos);
        vec3 tf = (nextPlane - hitPos) * idir;
        float ft = min(min(tf.x, tf.y), tf.z);
        t += ft + 0.001;
    }
    return false;
}

void main() {
    uint cascadeLevel = gl_WorkGroupID.z;
    uint probeIndex = gl_WorkGroupID.y * 16 + gl_WorkGroupID.x;
    uint threadIndex = gl_LocalInvocationID.z * 64 + gl_LocalInvocationID.y * 8 + gl_LocalInvocationID.x;
    
    float cascadeScale = pow(2.0, float(cascadeLevel));
    uint3 gridSize = uint3(pointerGridSize) / uint3(1, 1, 1) / uint(cascadeScale);
    
    if (probeIndex >= gridSize.x * gridSize.z) return;
    
    uint probeX = probeIndex % gridSize.x;
    uint probeZ = probeIndex / gridSize.x;
    
    vec3 voxelPos = vec3(probeX + 0.5, 0.5, probeZ + 0.5) * cascadeScale;
    voxelPos += vec3(0.0, float(gl_WorkGroupID.y) * cascadeScale, 0.0);
    
    if (voxelPos.y >= 64.0) return;
    
    int probeSize = int(3.0 * cascadeScale);
    if (probeSize < 3) probeSize = 3;
    
    vec2 probeUV = vec2(float(threadIndex % probeSize), float(threadIndex / probeSize));
    if (probeUV.x >= probeSize || probeUV.y >= probeSize) return;
    
    vec3 dir = ComputeDir(probeUV, float(probeSize));
    dir = (cameraRotationMatrix * vec4(dir, 0.0)).xyz;
    
    float t;
    vec3 hitPos;
    uvec4 voxel;
    vec3 radiance = vec3(0.0);
    
    if (TraceRay(voxelPos, dir, t, hitPos, voxel)) {
        if (voxel.w > 255) {
            radiance = UnpackColor(voxel);
        } else {
            float sunVis = GetSunVisibility(hitPos, dir);
            radiance = sunVis * GetSunLight();
            radiance += IntegrateVoxel(floor(hitPos), dir);
            radiance *= UnpackColor(voxel).rgb;
        }
    } else {
        radiance = GetSkyLight(dir);
    }
    
    float theta = acos(dir.y);
    float cosTheta = max(0.0, dir.y);
    radiance *= cosTheta;
    
    uint cascadeOffset = 0;
    for (int i = 0; i < 5; i++) {
        if (i == cascadeLevel) break;
        cascadeOffset += uint(pow(4.0, float(i)) * 9.0 * 32.0 * 48.0);
    }
    
    uint baseIndex = cascadeOffset + probeIndex * uint(probeSize * probeSize) + threadIndex;
    uint texWidth = 512;
    uint y = baseIndex / texWidth;
    uint x = baseIndex % texWidth;
    
    if (y < 8192) {
        // Use 2D imageStore for the atlas
        imageStore(radianceCascadesI, ivec2(x, int(LOD_POS[cascadeLevel]) + int(y)), vec4(radiance, 1.0));
    }
}
