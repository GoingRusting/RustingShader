#extension GL_ARB_shader_texture_lod : enable

#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/glow.glsl"

const bool colortex0MipmapEnabled = true;

uniform sampler2D colortex0;
uniform sampler2D colortex3;
uniform float viewWidth;
uniform float viewHeight;
uniform mat4 gbufferProjection;
uniform sampler2D depthtex0;
uniform ivec2 eyeBrightnessSmooth;

varying vec2 texcoord;

vec3 aces(vec3 x) {
    return clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), 0.0, 1.0);
}

void main() {
    vec3 color = texture2D(colortex0, texcoord).rgb;

#ifdef BLOOM

    vec3 bloom = vec3(0.0);
    vec2 texel = 1.0 / vec2(viewWidth, viewHeight);
    for (int i = 2; i <= 7; i++) {
        float lod = float(i);
        vec2 o = texel * exp2(lod) * 0.5;
        bloom += texture2D(colortex0, texcoord + vec2( o.x,  o.y), lod).rgb
               + texture2D(colortex0, texcoord + vec2(-o.x,  o.y), lod).rgb
               + texture2D(colortex0, texcoord + vec2( o.x, -o.y), lod).rgb
               + texture2D(colortex0, texcoord + vec2(-o.x, -o.y), lod).rgb;
    }
    color = mix(color, bloom / 24.0, BLOOM_STRENGTH);
#endif

#ifdef GLOW

    color += glowAt(colortex3, texcoord, vec2(viewWidth, viewHeight)) * GLOW_STRENGTH;
#endif

#ifdef LENS_FLARE
#ifndef NO_SKY

    vec4 sc = gbufferProjection * vec4(sunPosition, 1.0);
    if (sc.w > 0.0) {
        vec2 sunUV = sc.xy / sc.w * 0.5 + 0.5;
        vec2 aspect = vec2(viewWidth / viewHeight, 1.0);
        vec2 axis = 0.5 - sunUV;

        float vis = texture2D(depthtex0, sunUV).r == 1.0 ? 1.0 : 0.0;
        vis *= smoothstep(6.0, 60.0, luminance(texture2D(colortex0, sunUV, 3.0).rgb));
        vis *= 1.0 - smoothstep(0.15, 0.6, length(axis * aspect));
        if (vis > 0.0) {
            vec3 flare = vec3(0.0);
            for (int i = 1; i <= 3; i++) {
                float fi = float(i);
                vec2 gp = sunUV + axis * (0.7 + fi * 0.45);
                float size = 0.012 + 0.01 * fi;
                float r = length((texcoord - gp) * aspect) / size;
                flare += exp(-r * r * 2.0) * mix(vec3(1.0, 0.7, 0.4), vec3(0.4, 0.7, 1.0), fi / 3.0);
            }
            color += flare * vis * LENS_FLARE_STRENGTH * 0.08;
        }
    }
#endif
#endif

    float exposure = EXPOSURE;
#ifdef AUTO_EXPOSURE
    exposure *= mix(2.2, 1.0, float(eyeBrightnessSmooth.y) / 240.0);
#endif
    color = aces(color * exposure);
    color = pow(color, vec3(1.0 / 2.2));

    color = mix(vec3(luminance(color)), color, SATURATION);
    color = (color - 0.5) * CONTRAST + 0.5;

    vec3 grade = mix(vec3(0.93, 1.0, 1.06), vec3(1.04, 1.0, 0.95), smoothstep(0.1, 0.75, luminance(color)));
    color *= mix(vec3(1.0), grade, COLOR_GRADE);

    vec2 v = texcoord - 0.5;
    color *= 1.0 - dot(v, v) * VIGNETTE * 1.5;

#ifdef CINEMATIC_BARS
    if (abs(texcoord.y - 0.5) > 0.5 * viewWidth / (viewHeight * 2.39)) color = vec3(0.0);
#endif

    color += (ign(gl_FragCoord.xy) - 0.5) / 255.0;
    gl_FragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
