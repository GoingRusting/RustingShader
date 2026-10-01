#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/shadow.glsl"
#ifdef END
#include "/lib/end.glsl"
#endif

/*
const int  colortex0Format = RGBA16F;
const int  colortex1Format = RGBA16F;
const int  colortex2Format = RGBA16F;
const vec4 colortex2ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
const int  colortex3Format = RGBA16F;
const vec4 colortex0ClearColor = vec4(0.0, 0.0, 0.0, 1.0);
const vec4 colortex1ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
*/

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform mat4 gbufferModelView;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform vec3 cameraPosition;
uniform vec3 fogColor;
uniform float far;
uniform int moonPhase;
uniform int isEyeInWater;
uniform ivec2 eyeBrightnessSmooth;

varying vec2 texcoord;
varying vec3 sunDirV, sunLightV, lightV, lightWV, skyAmbV;

#include "/lib/clouds.glsl"

/* DRAWBUFFERS:0 */

vec3 viewPosAt(vec2 uv, float d) {
    vec4 p = gbufferProjectionInverse * vec4(vec3(uv, d) * 2.0 - 1.0, 1.0);
    return p.xyz / p.w;
}
vec3 toPlayer(vec3 vp) { return (gbufferModelViewInverse * vec4(vp, 1.0)).xyz; }
vec3 toShadow(vec3 pp) { return (shadowProjection * (shadowModelView * vec4(pp, 1.0))).xyz; }

vec3 envColor(vec3 dir, vec3 sunDir) {
#if defined END
    return endFog(dir);
#elif defined NO_SKY
    return toLinear(fogColor);
#else
    return skyColor(dir, sunDir);
#endif
}

vec3 sceneAt(vec2 uv, float d, vec3 sunDir) {
    vec3 c = texture2D(colortex0, uv).rgb;
#ifdef END
    if (d == 1.0) c = endSky(normalize(mat3(gbufferModelViewInverse) * viewPosAt(uv, 1.0)));
#endif
#ifndef NO_SKY
    if (d == 1.0) {
        vec3 dir = normalize(mat3(gbufferModelViewInverse) * viewPosAt(uv, 1.0));
        c += skyColor(dir, sunDir);
    #ifdef AURORA
        c += aurora(dir, sunDir);
    #endif
        float r = 0.02 * SUN_SIZE;
        float disk = smoothstep(cos(r * 1.2), cos(r), dot(dir, sunDir));
        vec3 sunCol = mix(vec3(1.0, 0.92, 0.82), vec3(1.0, 0.45, 0.15), sunsetFactor(sunDir));
        c += sunCol * disk * SUN_STRENGTH * 25.0 * (1.0 - rainStrength);
    #ifdef CUSTOM_MOON
        vec4 moon = moonColor(dir, -sunDir, moonPhase) * (1.0 - rainStrength * 0.9);
        c = c * (1.0 - moon.a) + moon.rgb;
    #endif
    }
#endif
    return c;
}

vec4 ssr(vec3 pos, vec3 dir) {
    vec3 stepv = dir * (0.3 + length(pos) * 0.02);
    pos += stepv * ign(gl_FragCoord.xy);
    for (int i = 0; i < 24; i++) {
        pos += stepv;
        vec4 clip = gbufferProjection * vec4(pos, 1.0);
        if (clip.w <= 0.0) break;
        vec2 uv = clip.xy / clip.w * 0.5 + 0.5;
        if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) break;
        float d = texture2D(depthtex0, uv).r;
        float diff = viewPosAt(uv, d).z - pos.z;
        if (diff > 0.0 && diff < length(stepv) * 1.5 + 0.2) {
            for (int j = 0; j < 5; j++) {
                stepv *= 0.5;
                pos += diff > 0.0 ? -stepv : stepv;
                clip = gbufferProjection * vec4(pos, 1.0);
                uv = clip.xy / clip.w * 0.5 + 0.5;
                d = texture2D(depthtex0, uv).r;
                diff = viewPosAt(uv, d).z - pos.z;
            }

            if (d == 1.0 || texture2D(colortex1, uv).a > 0.0 || abs(diff) > 1.0) return vec4(0.0);
            vec2 edge = smoothstep(0.0, 0.08, uv) * (1.0 - smoothstep(0.92, 1.0, uv));
            return vec4(texture2D(colortex0, uv).rgb, edge.x * edge.y);
        }
        stepv *= 1.2;
    }
    return vec4(0.0);
}

float phaseHG(float cosT, float g) {
    float g2 = g * g;
    return (1.0 - g2) / (12.566 * pow(1.0 + g2 - 2.0 * g * cosT, 1.5));
}

void main() {
    vec3  sunDir   = sunDirV;
    vec3  sunLight = sunLightV;
    vec3  L        = lightV;
    vec3  lightW   = lightWV;
    bool  under    = isEyeInWater == 1;
    float eyeSky   = float(eyeBrightnessSmooth.y) / 240.0;
    vec3  skyAmb   = skyAmbV;
    vec3  absorb   = vec3(0.38, 0.09, 0.07) / WATER_CLARITY;
    vec3  waterCol = vec3(WATER_R, WATER_G, WATER_B);

    float d0   = texture2D(depthtex0, texcoord).r;
    vec4  wat  = texture2D(colortex1, texcoord);
    vec3  vp0  = viewPosAt(texcoord, d0);
    vec3  pp0  = toPlayer(vp0);
    vec3  dir  = normalize(mat3(gbufferModelViewInverse) * vp0);
    float dist = length(vp0);
    vec3  color;

    if (wat.a > 0.0) {

        vec3  wN = wat.rgb;
        vec3  N = normalize(mat3(gbufferModelView) * wN);
        vec3  V = normalize(vp0);

        vec3  Rw = reflect(dir, wN);
        if (!under) Rw = normalize(vec3(Rw.x, max(Rw.y, 0.03), Rw.z));
        vec3  R = mat3(gbufferModelView) * Rw;
        float skyAccess = smoothstep(0.35, 0.85, wat.a);
        float shadow = getShadow(toShadow(pp0)) * skyAccess;
    #ifdef VOLUMETRIC_CLOUDS
        shadow *= cloudShadow(pp0 + cameraPosition, lightW);
    #endif
        vec3  skyGrey = mix(vec3(luminance(skyAmb)), skyAmb, 0.35);
        vec3  waterLight = sunLight * shadow * 0.25 + skyGrey * (0.6 * skyAccess + 0.03);

        vec2 ruv = texcoord + wat.xz * 0.025 * WATER_REFRACTION / (1.0 + dist * 0.1);
        float d1 = texture2D(depthtex1, ruv).r;
        if (d1 <= d0 || texture2D(colortex1, ruv).a == 0.0) { ruv = texcoord; d1 = texture2D(depthtex1, ruv).r; }
        vec3 bg  = sceneAt(ruv, d1, sunDir);
        vec3 vp1 = viewPosAt(ruv, d1);
        float thickness = under ? 0.0 : (d1 == 1.0 ? 64.0 : length(vp1 - vp0));

    #ifdef WATER_CAUSTICS
        if (!under && d1 < 1.0) {
            vec3 floorPos = toPlayer(vp1) + cameraPosition;
            bg *= 1.0 + caustics(floorPos.xz) * skyAccess * dayFactor(sunDir) * exp(-thickness * 0.15);
        }
    #endif

        vec3 trans = exp(-absorb * thickness);
        vec3 refracted = bg * trans + waterCol * waterLight * (1.0 - trans);

        vec3 refl = envColor(Rw, sunDir) * skyAccess + waterCol * 0.02;
    #ifdef VOLUMETRIC_CLOUDS
      #ifndef NO_SKY
        if (!under && skyAccess > 0.0) {
            vec4 cl = renderClouds(Rw, 4000.0, lightW, sunLight, skyAmb * 0.9, 0.5);
            refl = refl * cl.a + cl.rgb * skyAccess;
        }
      #endif
    #endif
        float NdotV = max(dot(N, -V), 0.02);
        float fresnel = 0.02 + 0.98 * pow(1.0 - NdotV, 5.0);
        if (under) {
            NdotV = abs(dot(N, V));
            fresnel = (1.0 - smoothstep(0.15, 0.4, NdotV)) * 0.85;
            refl = mix(waterCol * waterLight, bg, 0.3);
        }
    #ifdef WATER_REFLECTIONS
        else {
            vec4 hit = ssr(vp0, R);
            refl = mix(refl, hit.rgb, hit.a);
        }
    #endif

        vec3  H = normalize(L - V);
        float NdotH = max(dot(N, H), 0.0);
        float a2 = mix(0.0036, 0.04, smoothstep(10.0, 150.0, dist));
        float D = a2 / (3.14159 * pow(NdotH * NdotH * (a2 - 1.0) + 1.0, 2.0));
        float F = 0.02 + 0.98 * pow(1.0 - max(dot(H, -V), 0.0), 5.0);
        vec3 spec = under ? vec3(0.0) : sunLight * min(D * F * max(dot(N, L), 0.0), 20.0) * shadow;

        color = mix(refracted, refl, fresnel) + spec;

    #ifdef WATER_FOAM
        if (!under && d1 < 1.0) {
            vec2 wp = (pp0 + cameraPosition).xz;
            float t = frameTimeCounter * WATER_SPEED;
            float n = vnoise(wp * 3.0 + t * 0.4) * vnoise(wp * 7.0 - t * 0.7);
            float foam = 0.6 * smoothstep(0.35, 0.55, (1.0 - smoothstep(0.0, 0.6, thickness)) * (0.5 + n * 1.5));
            color = mix(color, (sunLight * shadow * 0.6 + skyAmb * skyAccess * 0.8 + 0.02) * 0.9, foam * 0.8);
        }
    #endif
    } else {
        color = sceneAt(texcoord, d0, sunDir);
        if (wat.a < 0.0 && d0 < 1.0) {

            float amount = -wat.a;
            vec3  Rw = reflect(dir, wat.rgb);
            Rw = normalize(vec3(Rw.x, max(Rw.y, 0.03), Rw.z));
            vec3  refl = envColor(Rw, sunDir) * 0.8;
        #ifdef WATER_REFLECTIONS
            vec4 hit = ssr(vp0, mat3(gbufferModelView) * Rw);
            refl = mix(refl, hit.rgb, hit.a);
        #endif
            float NdotV = max(dot(wat.rgb, -dir), 0.02);
            float fresnel = 0.02 + 0.98 * pow(1.0 - NdotV, 5.0);
            color = mix(color, refl, fresnel * amount);
        }
    }

#ifdef VOLUMETRIC_CLOUDS
  #ifndef NO_SKY
    {
        float maxD = d0 == 1.0 ? 1e6 : dist;
        vec4 cl = renderClouds(dir, maxD, lightW, sunLight, skyAmb * 0.9, ign(gl_FragCoord.xy));
        color = color * cl.a + cl.rgb;
    }
  #endif
#endif

#if defined END
    if (d0 < 1.0 && !under) {
        float fog = 1.0 - exp(-dist * 0.004 * FOG_DENSITY);
        fog = max(fog, smoothstep(far * 0.6, far, dist));
        color = mix(color, endFog(dir), fog);
    }
  #ifdef END_SMOKE

    if (!under) {
        float len  = d0 == 1.0 ? 300.0 : min(dist, 300.0);
        float stp  = len / 16.0;
        float dith = ign(gl_FragCoord.xy);
        float t    = frameTimeCounter;
        float g    = max(dot(dir, endHoleDir()), 0.0);
    #if END_STYLE == 0
        vec3  lc   = vec3(0.1, 0.1, 0.12) * 0.15 + vec3(0.9, 0.35, 0.1) * pow(g, 6.0) * 0.2 * BH_BRIGHTNESS;
    #else
        vec3  lc   = vec3(0.22, 0.07, 0.4) * 0.2 + vec3(0.9, 0.35, 0.1) * pow(g, 6.0) * 0.35 * BH_BRIGHTNESS;
    #endif
        vec3  acc  = vec3(0.0);
        float trans = 1.0;
        for (int i = 0; i < 16; i++) {
            vec3 p = cameraPosition + dir * stp * (float(i) + dith);
            float h = smoothstep(END_SMOKE_HEIGHT + 30.0, END_SMOKE_HEIGHT - 30.0, p.y);
            if (h <= 0.0) continue;
            float n = vnoise3(p * 0.025 + vec3(t * 0.04, -t * 0.02, t * 0.03)) * 0.65
                    + vnoise3(p * 0.08 - vec3(t * 0.07, t * 0.05, 0.0)) * 0.35;
            float dens = smoothstep(0.35, 0.8, n) * h * 0.02 * END_SMOKE_DENSITY;
            float T = exp(-dens * stp);
            acc += trans * (1.0 - T) * lc * (0.6 + n);
            trans *= T;
        }
        color = color * trans + acc;
    }
  #endif
#elif defined NO_SKY
    if (d0 < 1.0) color = mix(color, toLinear(fogColor), smoothstep(far * 0.4, far, dist) * 0.8);
#else
    if (d0 < 1.0 && !under) {
        float fog = 1.0 - exp(-dist * 0.0015 * FOG_DENSITY * (1.0 + rainStrength * 4.0));
        fog = max(fog, smoothstep(far * 0.75, far, dist));
        color = mix(color, skyColor(dir, sunDir), fog);
    }

  #ifdef GROUND_FOG

    if (!under) {
        float len = d0 == 1.0 ? far : dist;
        const float falloff = 1.0 / 12.0;
        float base = exp(-(cameraPosition.y - GROUND_FOG_HEIGHT) * falloff);
        float k = dir.y * falloff;
        float od = abs(k) > 1e-4 ? base * (1.0 - exp(-len * k)) / k : base * len;
        float amount = (0.6 + sunsetFactor(sunDir) * 2.5 + rainStrength * 2.0) * (0.5 + 0.5 * (1.0 - dayFactor(sunDir)));
        float gf = 1.0 - exp(-min(od, 1e4) * 0.004 * GROUND_FOG_DENSITY * amount);
        gf *= eyeSky;

        vec3 mist = sunLight * (phaseHG(dot(dir, lightW), 0.6) * 2.5 + 0.1) * eyeSky + skyAmb * 0.8 + 0.004;
        color = mix(color, mist, gf);
    }
  #endif

  #ifdef VOLUMETRIC_LIGHT

    if (!under && eyeSky > 0.0) {
        vec3 start = toPlayer(vec3(0.0));
        float len  = min(dist, shadowDistance);
        vec3 s0 = toShadow(start);
        vec3 s1 = toShadow(start + dir * len);
        float dith = ign(gl_FragCoord.xy);
        float lit = 0.0;
        for (int i = 0; i < VL_STEPS; i++) {
            float f = (float(i) + dith) / float(VL_STEPS);
            float s = getShadowFast(mix(s0, s1, f));
        #ifdef VOLUMETRIC_CLOUDS

            if (s > 0.0) s *= cloudShadow(start + dir * len * f + cameraPosition, lightW);
        #endif
            lit += s;
        }
        lit /= float(VL_STEPS);

        float phase  = phaseHG(dot(dir, lightW), 0.7) * 0.8 + 0.08;
        float amount = 1.0 - exp(-len * 0.006 * (1.0 + sunsetFactor(sunDir) * 2.0 + rainStrength * 3.0));
        color += sunLight * lit * phase * amount * VL_STRENGTH * eyeSky;
    }
  #endif
#endif

    if (under) {
        vec3 eyeLight = sunLight * 0.25 * eyeSky + skyAmb * 0.3 * eyeSky + 0.03;
        vec3 trans = exp(-absorb * 0.6 * dist);
        color = color * trans + waterCol * eyeLight * (1.0 - trans);

    #ifdef UNDERWATER_RAYS

        float len  = min(dist, 40.0);
        float dith = ign(gl_FragCoord.xy);
        float rays = 0.0;
        for (int i = 0; i < 10; i++) {
            float s  = (float(i) + dith) / 10.0 * len;
            vec3  pp = dir * s;
            vec3  wp = pp + cameraPosition;
            vec2  cp = wp.xz - lightW.xz * (wp.y / max(lightW.y, 0.25));
            rays += getShadowFast(toShadow(pp)) * (0.25 + caustics(cp * 0.35)) * exp(-s * 0.07);
        }
        rays *= len / 10.0;
        color += sunLight * waterCol * rays * phaseHG(dot(dir, lightW), 0.5) * 0.6 * UNDERWATER_RAYS_STRENGTH * eyeSky;
    #endif
    } else if (isEyeInWater == 2) {
        color = mix(color, vec3(1.2, 0.25, 0.02), 1.0 - exp(-dist * 0.8));
    } else if (isEyeInWater == 3) {
        color = mix(color, vec3(0.7, 0.8, 0.9), 1.0 - exp(-dist * 0.8));
    }

    gl_FragData[0] = vec4(color, 1.0);
}
