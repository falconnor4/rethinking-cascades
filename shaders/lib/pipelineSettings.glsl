/*
const int colortex0Format = RGBA16F;		//main color
const int colortex1Format = RGBA8;			//smoothnessD & materialMask & skyLightFactor & SSS
const int colortex2Format = RGBA16F;		//taa, previous depth
const int colortex3Format = RGB8;			//*cloud map on deferred* & translucentMult & bloom & final color
const int colortex4Format = RGBA8;			//volumetric cloud linear depth & volumetric light factor & normals in composite
const int colortex5Format = RGBA8_SNORM;	//normalM & scene image for water reflections
const int colortex6Format = R8;				//*cloud texture on gbuffers*
#ifdef TEMPORAL_FILTER
const int colortex6Format = R16;		    //previous depth
const int colortex7Format = RGBA16F;		//*cloud map on gbuffers* & temporal filter
#endif
const int colortex8Format = RGBA16F; // normal and depth data in prepare
const int colortex9Format = R32UI; // integer depth for sorting
const int shadowcolor0Format = RGBA16;
const int shadowcolor1Format = RGBA16;
const int colortex12Format = RGBA16F;		//previous frame lighting
const int colortex16Format = RGBA32F;		//radiance cascades
 */

const bool colortex0Clear = true;
const vec4 colortex0ClearColor = vec4(2.0, 2.0, 2.0, 2.0);
const bool colortex1Clear = false;
const bool colortex2Clear = false;
const bool colortex3Clear = true;
const bool colortex4Clear = false;
const bool colortex5Clear = false;
#ifdef TEMPORAL_FILTER
const bool colortex6Clear = false;
const bool colortex7Clear = false;
#endif
// temporal voxel data such as flood fill

const bool colortex12Clear = false;
const bool colortex16Clear = false;

const int noiseTextureResolution = 128;

const bool shadowHardwareFiltering = true;
const float shadowDistanceRenderMul = 1.0;
const float entityShadowDistanceMul = 1.0; // Iris devs may bless us with their power

const float drynessHalflife = 300.0;
const float wetnessHalflife = 300.0;

const float ambientOcclusionLevel = 1.0;
