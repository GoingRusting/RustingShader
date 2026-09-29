#include "/lib/settings.glsl"
#include "/lib/common.glsl"

uniform int renderStage;
varying vec4 glcolor;

void main() {
    vec3 c = vec3(0.0);
#ifdef MC_RENDER_STAGE_STARS
    if (renderStage == MC_RENDER_STAGE_STARS) {

        float h = hash12(floor(gl_FragCoord.xy / 3.0));
        float twinkle = 0.65 + 0.35 * sin(frameTimeCounter * (2.0 + h * 4.0) + h * 40.0);
        vec3 tint = mix(vec3(1.0, 0.85, 0.7), vec3(0.75, 0.85, 1.0), h);
        c = glcolor.rgb * tint * twinkle * STAR_BRIGHTNESS;
    }
#endif
    gl_FragData[0] = vec4(c, glcolor.a);
}
