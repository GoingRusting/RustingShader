#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#ifdef END
#include "/lib/end.glsl"
#endif

uniform vec3 shadowLightPosition;
uniform vec3 fogColor;

varying vec2 texcoord;
varying vec3 sunDirV;
varying vec3 sunLightV;
varying vec3 lightV;
varying vec3 lightWV;
varying vec3 skyAmbV;

void main() {
    texcoord = gl_MultiTexCoord0.xy;
    gl_Position = ftransform();

    sunDirV   = sunDirWorld();
    sunLightV = directLightColor(sunDirV);
    lightV    = normalize(shadowLightPosition + vec3(0.0, 1e-4, 0.0));
    lightWV   = mat3(gbufferModelViewInverse) * lightV;
#if defined END
    skyAmbV = endFog(vec3(0.0, 1.0, 0.0));
#elif defined NO_SKY
    skyAmbV = toLinear(fogColor);
#else
    skyAmbV = skyColor(vec3(0.0, 1.0, 0.0), sunDirV);
#endif
}
