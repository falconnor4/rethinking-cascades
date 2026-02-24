#ifndef LIGHTING
	#define LIGHTING
	#ifndef COLORTEX12
		#define COLORTEX12
		uniform sampler2D colortex12;
	#endif
	#include "/lib/vx/voxelMapping.glsl"
	#include "/lib/vx/SSBOs.glsl"
	
	#ifdef RADIANCE_CASCADES
		#include "/lib/vx/radianceCascades.glsl"
	#elif defined(ADVANCED_LIGHT_TRACING)
		#include "/lib/vx/radianceCascades.glsl"
	#endif

	#ifdef PER_BLOCK_LIGHT
		vec3 getBlockLight(vec3 vxPos, vec3 worldNormal, int mat, bool doScattering) {
			#if defined(RADIANCE_CASCADES) || defined(ADVANCED_LIGHT_TRACING)
				vec3 worldPos = getWorldPos(vxPos);
				return getRadianceCascadesLighting(worldPos, worldNormal);
			#else
				if (length(worldNormal) > 0.01)
					return readIrradianceCache(vxPos + 0.5 * worldNormal, worldNormal);
				else
					return readIrradianceCache(vxPos, 6);
			#endif
		}
	#else
		vec3 getBlockLight(vec3 vxPos, vec3 worldNormal, int mat, bool doScattering) {
			vec3 screenPos = gl_FragCoord.xyz / vec3(textureSize(colortex12, 0), 1);
			vec4 prevCol = texture2D(colortex12, screenPos.xy);

			#if defined(RADIANCE_CASCADES) || defined(ADVANCED_LIGHT_TRACING)
				vec3 worldPos = getWorldPos(vxPos);
				return prevCol.xyz * 2.0 + getRadianceCascadesLighting(worldPos, worldNormal);
			#else
				return prevCol.xyz * 2;
			#endif
		}
	#endif

	vec3 getBlockLight(vec3 vxPos, vec3 normal, int mat) {
		return getBlockLight(vxPos, normal, mat, false);
	}
	vec3 getBlockLight(vec3 vxPos) {
		return getBlockLight(vxPos, vec3(0), 0, false);
	}
#endif
