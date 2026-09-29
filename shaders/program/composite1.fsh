#extension GL_ARB_shader_texture_lod : enable

#include "/lib/settings.glsl"
#include "/lib/glow.glsl"

const bool colortex2MipmapEnabled = true;

uniform sampler2D colortex2;
uniform float viewWidth;
uniform float viewHeight;

varying vec2 texcoord;

void main() {
#ifdef GLOW
    gl_FragData[0] = vec4(glowTiles(colortex2, texcoord, 1.0 / vec2(viewWidth, viewHeight)), 1.0);
#else
    gl_FragData[0] = vec4(0.0);
#endif
}
