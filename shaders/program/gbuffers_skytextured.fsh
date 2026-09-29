#include "/lib/settings.glsl"

uniform sampler2D texture;
uniform int renderStage;
varying vec2 texcoord;
varying vec4 glcolor;

void main() {
#ifdef MC_RENDER_STAGE_SUN
    if (renderStage == MC_RENDER_STAGE_SUN) discard;
#endif
#if defined MC_RENDER_STAGE_MOON && defined CUSTOM_MOON
    if (renderStage == MC_RENDER_STAGE_MOON) discard;
#endif
    vec4 c = texture2D(texture, texcoord) * glcolor;
    gl_FragData[0] = vec4(pow(c.rgb, vec3(2.2)) * SUN_MOON_BRIGHTNESS, c.a);
}
