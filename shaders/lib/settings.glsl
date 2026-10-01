const int shadowMapResolution = 2048; // [1024 2048 3072 4096]
const float shadowDistance = 128.0; // [64.0 96.0 128.0 160.0 192.0 256.0]
const float sunPathRotation = -30.0; // [-45.0 -30.0 -15.0 0.0 15.0 30.0 45.0]
#define SHADOW_SOFTNESS 1.5 // [0.0 0.5 1.0 1.5 2.0 3.0 4.0]
#define SHADOW_DISTORT 0.85 // [0.7 0.8 0.85 0.9]

#define SUN_STRENGTH 2.6       // [1.0 1.5 2.0 2.6 3.0 4.0 5.0]
#define MOON_STRENGTH 0.35     // [0.1 0.2 0.35 0.5 0.8]

#define CUSTOM_MOON
#define MOON_SIZE 2.0          // [0.5 0.75 1.0 1.5 2.0 3.0]
#define MOON_BRIGHTNESS 1.2    // [0.5 0.8 1.2 2.0 3.0]

#define PUDDLES
#define PUDDLE_AMOUNT 1.0      // [0.5 1.0 1.5 2.0]
#define RAIN_OPACITY 0.4       // [0.1 0.2 0.3 0.4 0.6 0.8 1.0]
#define AMBIENT_STRENGTH 0.55  // [0.2 0.35 0.45 0.55 0.7 0.9 1.2]
#define TORCH_STRENGTH 1.6     // [0.5 1.0 1.6 2.0 3.0 4.0]
#define EMISSIVE_STRENGTH 4.0  // [0.0 1.0 2.0 4.0 6.0 8.0]
#define GLOW
#define GLOW_STRENGTH 1.0      // [0.0 0.25 0.5 0.75 1.0 1.5 2.0 3.0]
#define GLOWING_ORES
#define DYNAMIC_LIGHT
#define TORCH_R 1.00 // [0.6 0.7 0.8 0.9 1.0]
#define TORCH_G 0.55 // [0.3 0.4 0.5 0.55 0.6 0.7 0.8]
#define TORCH_B 0.22 // [0.1 0.2 0.22 0.3 0.4 0.5]

#define WAVING_PLANTS
#define WAVE_SPEED 1.0     // [0.5 0.75 1.0 1.5 2.0]
#define WAVE_AMPLITUDE 1.0 // [0.0 0.5 1.0 1.5 2.0 3.0]

#define WATER_R 0.04 // [0.0 0.02 0.04 0.08 0.15]
#define WATER_G 0.30 // [0.15 0.22 0.30 0.40 0.50]
#define WATER_B 0.36 // [0.2 0.28 0.36 0.45 0.6]
#define WATER_CLARITY 1.0     // [0.3 0.5 0.75 1.0 1.5 2.0 3.0]
#define WATER_WAVE_HEIGHT 1.0 // [0.0 0.25 0.5 0.75 1.0 1.5 2.0]
#define WATER_SPEED 1.0       // [0.25 0.5 1.0 1.5 2.0]
#define WATER_REFRACTION 1.0  // [0.0 0.5 1.0 1.5 2.0]
#define WATER_FOAM
#define WATER_CAUSTICS
#define WATER_REFLECTIONS

#define UNDERWATER_RAYS
#define UNDERWATER_RAYS_STRENGTH 1.0 // [0.25 0.5 1.0 1.5 2.0 3.0]

#define VOLUMETRIC_CLOUDS
#define CLOUD_COVERAGE 0.5   // [0.2 0.3 0.4 0.45 0.5 0.6 0.7 0.8]
#define CLOUD_HEIGHT 200.0   // [140.0 170.0 200.0 240.0 300.0]
#define CLOUD_THICKNESS 110.0 // [60.0 80.0 110.0 150.0 200.0]
#define CLOUD_SPEED 1.0      // [0.0 0.5 1.0 2.0 4.0]
#define CLOUD_STEPS 24       // [12 16 24 32 48]

#define VOLUMETRIC_LIGHT
#define VL_STRENGTH 1.0 // [0.25 0.5 0.75 1.0 1.5 2.0 3.0]
#define VL_STEPS 12     // [6 8 12 16 24]
#define SUN_SIZE 1.0    // [0.5 0.75 1.0 1.5 2.0 3.0]
#define FOG_DENSITY 1.0      // [0.0 0.5 1.0 1.5 2.0 3.0]
#define STAR_BRIGHTNESS 3.0  // [1.0 2.0 3.0 5.0]
#define SUN_MOON_BRIGHTNESS 6.0 // [2.0 4.0 6.0 10.0]

#define GROUND_FOG
#define GROUND_FOG_DENSITY 1.0 // [0.25 0.5 1.0 1.5 2.0 3.0]
#define GROUND_FOG_HEIGHT 64.0 // [40.0 50.0 64.0 72.0 80.0 100.0]

#define AURORA
#define AURORA_STRENGTH 1.0 // [0.25 0.5 1.0 1.5 2.0 3.0]

#define BLOOM
#define BLOOM_STRENGTH 0.12 // [0.04 0.08 0.12 0.18 0.25 0.35]
#define EXPOSURE 1.0        // [0.5 0.7 0.85 1.0 1.2 1.5 2.0]
#define SATURATION 1.15     // [0.8 0.9 1.0 1.1 1.15 1.25 1.4]
#define CONTRAST 1.05       // [0.9 1.0 1.05 1.1 1.2]
#define VIGNETTE 0.35       // [0.0 0.15 0.25 0.35 0.5 0.75]
#define COLOR_GRADE 1.0     // [0.0 0.5 1.0 1.5 2.0]
//#define CINEMATIC_BARS

#define AUTO_EXPOSURE
#define LENS_FLARE
#define LENS_FLARE_STRENGTH 1.0 // [0.25 0.5 1.0 1.5 2.0]

#define END_STYLE 0    // [0 1]
#define BH_SIZE 2.0        // [0.5 0.75 1.0 1.5 2.0 3.0]
#define BH_SPIN 1.0        // [0.0 0.5 1.0 2.0 4.0]
#define BH_BRIGHTNESS 1.0  // [0.5 0.75 1.0 1.5 2.0]
#define END_NEBULA 1.0     // [0.0 0.5 1.0 1.5 2.0 3.0]

#define END_SMOKE
#define END_SMOKE_DENSITY 1.0 // [0.25 0.5 1.0 1.5 2.0 3.0]
#define END_SMOKE_HEIGHT 80.0 // [40.0 50.0 60.0 70.0 80.0 90.0 100.0 120.0]
