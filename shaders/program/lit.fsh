#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/shadow.glsl"

uniform vec3 cameraPosition;
#include "/lib/clouds.glsl"
#ifdef END
#include "/lib/end.glsl"
#endif

uniform sampler2D texture;
uniform sampler2D lightmap;
uniform vec3 shadowLightPosition;
uniform vec4 entityColor;
uniform float wetness;
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;
#if defined ENTITIES || defined HAND
uniform int entityId;
uniform int currentRenderedItemId;
#endif

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

vec3 emission(float id, vec3 albedo, vec3 color) {
    float mx  = max(albedo.r, max(albedo.g, albedo.b));
    float sat = mx - min(albedo.r, min(albedo.g, albedo.b));
    float colored = smoothstep(0.2, 0.55, sat) * smoothstep(0.35, 0.8, mx);
    if (id == 10005.0) return color * smoothstep(0.3, 0.8, luminance(albedo));
    if (id == 10006.0) {

        float red = clamp((albedo.r - max(albedo.g, albedo.b)) * 2.5, 0.0, 1.0) * smoothstep(0.3, 1.0, albedo.r);
        return vec3(1.0, 0.07, 0.03) * red * (0.3 + 0.35 * albedo.r);
    }
    if (id == 10007.0) return color * colored * 1.2;
    if (id == 10008.0) return color * clamp((albedo.r - albedo.b) * 2.0, 0.0, 1.0) * smoothstep(0.6, 0.95, albedo.r);
    if (id == 10009.0) return color * smoothstep(0.3, 0.8, luminance(albedo));
#ifdef GLOWING_ORES
    if (id == 10010.0) return color * colored * 0.35;
#endif
    if (id == 10011.0) return color;
    return vec3(0.0);
}

void main() {

    float id = floor(blockId + 0.5);
#if defined ENTITIES || defined HAND
    id = 0.0;
    if (currentRenderedItemId > 0) id = float(currentRenderedItemId);
    else if (entityId > 0) id = float(entityId);
#endif
#ifdef EYES
    id = 10011.0;
#endif
#ifdef NO_TEXTURE
    vec4 albedo = glcolor;
#else
    vec4 albedo = texture2D(texture, texcoord) * glcolor;
#endif
#ifdef ENTITIES
    albedo.rgb = mix(albedo.rgb, entityColor.rgb, entityColor.a);
#endif
    if (albedo.a < 0.1) discard;

#ifdef WEATHER

    {
        vec3 light = skyAmbV * 0.8 * lmcoord.y + toLinear(texture2D(lightmap, lmcoord).rgb) * 0.3
                   + sunLightV * 0.05 * lmcoord.y;
        float l = luminance(albedo.rgb);
        gl_FragData[0] = vec4(vec3(0.8 + l * 0.4) * light, albedo.a * RAIN_OPACITY * (0.5 + l * 0.5));
        return;
    }
#endif

#ifdef WATER

    if (id == 10003.0) {
        vec3 wN = mat3(gbufferModelViewInverse) * normalize(viewNormal);
        if (wN.y > 0.5) wN = waterNormal(worldPos.xz, length(viewPos));
        gl_FragData[0] = vec4(0.0);
        gl_FragData[1] = vec4(wN, max(lmcoord.y, 0.01));
        gl_FragData[2] = vec4(0.0);
        return;
    }
    gl_FragData[1] = vec4(0.0);
#endif

    vec3 color = toLinear(albedo.rgb);
    float alpha = albedo.a;
    vec3 emit = emission(id, albedo.rgb, color) * EMISSIVE_STRENGTH;
#ifdef PARTICLES

    emit = color * smoothstep(0.93, 0.96, lmcoord.x) * smoothstep(0.5, 0.9, max(albedo.r, max(albedo.g, albedo.b))) * EMISSIVE_STRENGTH * 0.5;
#endif

#ifndef UNLIT
    vec3  lightDir = normalize(shadowLightPosition + vec3(0.0, 1e-4, 0.0));
    vec3  N        = normalize(viewNormal);
    bool  foliage  = id == 10001.0 || id == 10002.0 || id == 10004.0;
    float NdotL    = foliage ? 0.6 : max(dot(N, lightDir), 0.0);
#ifdef END
    float skyAccess = 1.0;
#else
    float skyAccess = smoothstep(0.35, 0.85, lmcoord.y);
#endif
#ifdef NO_SHADOW
    float shadow   = 1.0;
#else

    float shadow   = NdotL > 0.0 && skyAccess > 0.0 ? getShadow(shadowPos) : 0.0;
  #ifdef VOLUMETRIC_CLOUDS
    if (shadow > 0.0) shadow *= cloudShadow(worldPos, mat3(gbufferModelViewInverse) * lightDir);
  #endif
#endif

#ifdef END

  #if END_STYLE == 0
    vec3 sunLight = vec3(0.42, 0.42, 0.5) * 0.3;
  #else
    vec3 sunLight = vec3(0.55, 0.4, 0.85) * 0.35;
  #endif
#else
    vec3 sunLight = sunLightV;
#endif
    vec3 direct   = sunLight * NdotL * shadow * skyAccess;
#ifdef NO_SKY

    vec3 ambient  = toLinear(texture2D(lightmap, vec2(1.0 / 32.0, lmcoord.y)).rgb) * AMBIENT_STRENGTH;
#else

    float sky = clamp((lmcoord.y - 1.0 / 32.0) * 16.0 / 15.0, 0.0, 1.0);
    vec3 ambient  = skyAmbV * sky * sky * AMBIENT_STRENGTH + vec3(0.006, 0.007, 0.009);
#endif
#ifdef END
  #if END_STYLE == 0
    ambient *= vec3(0.26, 0.26, 0.3);
  #else
    ambient *= vec3(0.3, 0.26, 0.45);
  #endif
    vec3 wN = mat3(gbufferModelViewInverse) * normalize(viewNormal);
    ambient += vec3(1.0, 0.45, 0.15) * max(dot(wN, endHoleDir()), 0.0) * 0.05;
#endif
    float upness = (mat3(gbufferModelViewInverse) * N).y;
    ambient *= foliage ? 0.9 : 0.72 + 0.28 * upness;
    float blockLight = lmcoord.x;
#ifdef DYNAMIC_LIGHT

    float held = float(max(heldBlockLightValue, heldBlockLightValue2));
    blockLight = max(blockLight, clamp((held - length(viewPos)) / 15.0, 0.0, 1.0) * 0.95);
#endif

    blockLight = clamp((blockLight - 1.0 / 32.0) * 16.0 / 15.0, 0.0, 1.0);
    vec3 torch    = vec3(TORCH_R, TORCH_G, TORCH_B) * pow(blockLight, 2.5) * TORCH_STRENGTH;

    if (foliage) {
        float back = pow(max(dot(normalize(viewPos), lightDir), 0.0), 4.0);
        direct += sunLight * shadow * skyAccess * back * 1.2;
    }

    float wet = wetness * skyAccess * clamp(upness * 1.5, 0.0, 1.0);
    float puddle = 0.0;
#ifdef PUDDLES
  #ifdef TERRAIN
    if (!foliage && upness > 0.9 && wet > 0.01) {
        float n = vnoise(worldPos.xz * 0.11) * 0.65 + vnoise(worldPos.xz * 0.47) * 0.35;
        float edge = 0.78 - 0.22 * wet * PUDDLE_AMOUNT;
        puddle = smoothstep(edge, edge + 0.06, n) * wet;
    }
#endif
#endif
    color = mix(color, pow(color, vec3(1.5)) * 0.8, max(wet * 0.6, puddle * 0.9));

    color *= ambient + direct + torch;
#endif
    color += emit;

    gl_FragData[0] = vec4(color, alpha);
#ifdef DATA_OUT
  #ifdef UNLIT
    gl_FragData[1] = vec4(0.0);
  #else

    vec3 nW = mat3(gbufferModelViewInverse) * N;
    if (puddle > 0.0) nW = normalize(vec3(rainRipples(worldPos.xz) * 0.3 * rainStrength, 1.0).xzy);
  #ifdef TERRAIN
    float refl = max(wet * 0.3, puddle);
  #else
    float refl = 0.0;
  #endif
    gl_FragData[1] = refl > 0.01 ? vec4(nW, -refl) : vec4(0.0);
  #endif
#endif
#ifdef EMISSIVE_OUT

  #ifdef HAND
    emit *= 0.2;
  #endif
    gl_FragData[2] = vec4(emit * (id == 10009.0 ? 0.25 : 1.0), alpha);
#endif
}
