#include "/lib/settings.glsl"
#include "/lib/common.glsl"

attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;

uniform mat4 gbufferModelView;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform vec3 cameraPosition;

varying vec2 texcoord;
varying vec2 lmcoord;
varying vec4 glcolor;
varying vec3 viewNormal;
varying vec3 viewPos;
varying vec3 worldPos;
varying vec3 shadowPos;
varying float blockId;

varying vec3 sunLightV;
varying vec3 skyAmbV;

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
#ifdef CLOUDS
    lmcoord = vec2(1.0 / 32.0, 31.0 / 32.0);
#endif
    glcolor    = gl_Color;
    blockId    = mc_Entity.x;
    viewNormal = normalize(gl_NormalMatrix * gl_Normal);

    vec4 vp = gl_ModelViewMatrix * gl_Vertex;
    vec3 playerPos = (gbufferModelViewInverse * vp).xyz;

#ifdef TERRAIN
#ifdef WAVING_PLANTS
    bool isTop = gl_MultiTexCoord0.t < mc_midTexCoord.t;
    playerPos += waveOffset(playerPos + cameraPosition, mc_Entity.x, isTop);
    vp = gbufferModelView * vec4(playerPos, 1.0);
#endif
#endif

    viewPos  = vp.xyz;
    worldPos = playerPos + cameraPosition;

    vec3 worldNormal = mat3(gbufferModelViewInverse) * viewNormal;
    vec3 biased = playerPos + worldNormal * (0.03 + length(playerPos) * 0.004);
    shadowPos = (shadowProjection * (shadowModelView * vec4(biased, 1.0))).xyz;

    gl_Position = gl_ProjectionMatrix * vp;

    vec3 sunDir = sunDirWorld();
    sunLightV = directLightColor(sunDir);
    skyAmbV = vec3(0.0);
#ifdef WEATHER
    skyAmbV = skyColor(vec3(0.0, 1.0, 0.0), sunDir);
#elif !defined NO_SKY

    skyAmbV = skyColor(vec3(0.0, 1.0, 0.0), sunDir) + skyColor(normalize(vec3(-sunDir.x, 0.15, -sunDir.z)), sunDir);
    skyAmbV = mix(vec3(luminance(skyAmbV)), skyAmbV, 0.6);
    skyAmbV += sunLightV * (1.0 - dayFactor(sunDir)) * 0.25;
#endif
}
