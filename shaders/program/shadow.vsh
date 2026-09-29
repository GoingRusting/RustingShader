#include "/lib/settings.glsl"
#include "/lib/common.glsl"

attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;

uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform vec3 cameraPosition;

varying vec2 texcoord;
varying vec4 glcolor;

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    glcolor  = gl_Color;

    if (mc_Entity.x == 10003.0) {
        gl_Position = vec4(10.0);
        return;
    }

    vec4 vp = gl_ModelViewMatrix * gl_Vertex;

#ifdef WAVING_PLANTS
    vec3 playerPos = (shadowModelViewInverse * vp).xyz;
    playerPos += waveOffset(playerPos + cameraPosition, mc_Entity.x, gl_MultiTexCoord0.t < mc_midTexCoord.t);
    vp = shadowModelView * vec4(playerPos, 1.0);
#endif

    gl_Position = gl_ProjectionMatrix * vp;
    gl_Position.xyz = distortShadow(gl_Position.xyz);
}
