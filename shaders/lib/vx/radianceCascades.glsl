#ifndef RADIANCE_CASCADES
#define RADIANCE_CASCADES

#include "/shaders/lib/vx/SSBOs.glsl"

const int NUM_CASCADES = 5;
const float I32 = 1.0 / 32.0;
const float I48 = 1.0 / 48.0;
const float LOD_POS[5] = float[5](0.0, 2592.0, 3888.0, 4536.0, 4860.0);
const float LOD_MAX_POS = 5022.0;
const float CASCADE_ATLAS_WIDTH = 512.0;
const float CASCADE_ATLAS_HEIGHT = 8192.0;

#ifdef READONLY
    // radianceCascades is defined in SSBOs.glsl
    
    vec2 ProjectDir(vec3 dir, float probeSize) {
        if (dir.z <= 0.0) return vec2(-1.0);
        float thetai = min(floor((1.0 - acos(length(dir.xy) / length(dir)) / (3.141592653 * 0.5)) * (probeSize * 0.5)), probeSize * 0.5 - 1.0);
        float phiF = atan(-dir.x, -dir.y);
        float phiI = floor((phiF / 3.141592653 * 0.5 + 0.5) * (4.0 + 8.0 * thetai) + 0.5) + 0.5;
        vec2 phiUV;
        float phiLen = 2.0 * thetai + 1.0;
        float sideLen = phiLen + 1.0;
        if (phiI < phiLen) phiUV = vec2(sideLen - 0.5, sideLen - phiI);
        else if (phiI < phiLen * 2.0) phiUV = vec2(sideLen - (phiI - phiLen), 0.5);
        else if (phiI < phiLen * 3.0) phiUV = vec2(0.5, phiI - phiLen * 2.0);
        else phiUV = vec2(phiI - phiLen * 3.0, sideLen - 0.5);
        return vec2((probeSize - sideLen) * 0.5) + phiUV;
    }
    
    vec4 readRadianceCascade(vec3 vxPos, vec3 direction, int cascadeLevel) {
        float cascadeScale = pow(2.0, float(cascadeLevel));
        float probeSize = 3.0 * cascadeScale;
        
        vec3 gridSize = vec3(pointerGridSize);
        vec3 cascadeGrid = gridSize / cascadeScale;
        
        vec3 probePos = floor(vxPos / probeSize + 0.5) * probeSize;
        probePos = clamp(probePos, vec3(0.0), gridSize - probeSize);
        
        vec3 probeCell = probePos / probeSize;
        uint probeIndex = uint(probeCell.x) + uint(probeCell.z) * uint(cascadeGrid.x);
        
        vec2 dirUV = ProjectDir(direction, probeSize);
        if (dirUV.x < 0.0) return vec4(0.0);
        
        float dirIndex = floor(dirUV.x) + floor(dirUV.y) * probeSize;
        
        float lodOffset = LOD_POS[cascadeLevel];
        
        uint raysPerProbe = uint(probeSize * probeSize);
        uint cascadeOffset = 0;
        for (int i = 0; i < 5; i++) {
            if (i >= cascadeLevel) break;
            cascadeOffset += uint(pow(4.0, float(i))) * 9 * 32 * 48;
        }
        
        uint baseIndex = cascadeOffset + probeIndex * uint(probeSize * probeSize) + uint(dirIndex);
        
        vec2 texCoord = vec2(
            (mod(float(baseIndex), CASCADE_ATLAS_WIDTH) + 0.5) / CASCADE_ATLAS_WIDTH,
            (floor(float(baseIndex) / CASCADE_ATLAS_WIDTH) + 0.5 + lodOffset) / CASCADE_ATLAS_HEIGHT
        );
        
        return textureLod(radianceCascades, texCoord, float(cascadeLevel));
    }
    
    vec3 getRadianceCascadesLighting(vec3 worldPos, vec3 normal) {
        vec3 vxPos = getVxPos(worldPos);
        if (!isVxPosValid(vxPos)) return vec3(0.0);
        
        vec3 result = vec3(0.0);
        float totalWeight = 0.0;
        
        for (int i = 0; i < NUM_CASCADES; i++) {
            float cascadeScale = pow(2.0, float(i));
            float probeSize = 3.0 * cascadeScale;
            
            float dist = length(fract(vxPos / probeSize + 0.5) - 0.5) * probeSize;
            float weight = 1.0 / (1.0 + dist * dist * 0.01);
            
            vec4 radiance = readRadianceCascade(vxPos, normal, i);
            if (radiance.w > 0.0) {
                result += radiance.rgb * weight;
                totalWeight += weight;
            }
        }
        
        return totalWeight > 0.0 ? result / totalWeight : vec3(0.0);
    }
#else
    // radianceCascadesI is defined in SSBOs.glsl
    
    void writeRadianceCascade(ivec3 coord, vec4 data) {
        imageStore(radianceCascadesI, coord, data);
    }
    
    vec4 readRadianceCascadeI(ivec3 coord) {
        return imageLoad(radianceCascadesI, coord);
    }
    
    vec3 ComputeDirEven(vec2 uv, float probeSize) {
        vec2 probeRel = uv - probeSize * 0.5;
        float probeThetai = max(abs(probeRel.x), abs(probeRel.y));
        float probeTheta = probeThetai / probeSize * 3.14192653;
        float probePhi = 0.0;
        if (probeRel.x + 0.5 > probeThetai && probeRel.y - 0.5 > -probeThetai) {
            probePhi = probeRel.x - probeRel.y;
        } else if (probeRel.y - 0.5 < -probeThetai && probeRel.x - 0.5 > -probeThetai) {
            probePhi = probeThetai * 2.0 - probeRel.y - probeRel.x;
        } else if (probeRel.x - 0.5 < -probeThetai && probeRel.y + 0.5 < probeThetai) {
            probePhi = probeThetai * 4.0 - probeRel.x + probeRel.y;
        } else if (probeRel.y + 0.5 > probeThetai && probeRel.x + 0.5 < probeThetai) {
            probePhi = probeThetai * 8.0 - (probeRel.y - probeRel.x);
        }
        probePhi = probePhi * 3.141592653 * 2.0 / (4.0 + 8.0 * floor(probeThetai));
        return vec3(vec2(sin(probePhi), cos(probePhi)) * sin(probeTheta), cos(probeTheta));
    }
    
    vec3 ComputeDir(vec2 uv, float probeSize) {
        if (probeSize > 4.5) return ComputeDirEven(uv, probeSize);
        vec2 probeRel = uv - 1.5;
        if (length(probeRel) < 0.1) return vec3(0.0, 0.0, 1.0);
        float probePhi = atan(probeRel.x, probeRel.y) + 3.141592653 * 1.75;
        float probeTheta = 3.141592653 * 0.25;
        return vec3(vec2(sin(probePhi), cos(probePhi)) * sin(probeTheta), cos(probeTheta));
    }
    
    vec2 ProjectDir(vec3 dir, float probeSize) {
        if (dir.z <= 0.0) return vec2(-1.0);
        float thetai = min(floor((1.0 - acos(length(dir.xy) / length(dir)) / (3.141592653 * 0.5)) * (probeSize * 0.5)), probeSize * 0.5 - 1.0);
        float phiF = atan(-dir.x, -dir.y);
        float phiI = floor((phiF / 3.141592653 * 0.5 + 0.5) * (4.0 + 8.0 * thetai) + 0.5) + 0.5;
        vec2 phiUV;
        float phiLen = 2.0 * thetai + 1.0;
        float sideLen = phiLen + 1.0;
        if (phiI < phiLen) phiUV = vec2(sideLen - 0.5, sideLen - phiI);
        else if (phiI < phiLen * 2.0) phiUV = vec2(sideLen - (phiI - phiLen), 0.5);
        else if (phiI < phiLen * 3.0) phiUV = vec2(0.5, phiI - phiLen * 2.0);
        else phiUV = vec2(phiI - phiLen * 3.0, sideLen - 0.5);
        return vec2((probeSize - sideLen) * 0.5) + phiUV;
    }
    
#endif
#endif
