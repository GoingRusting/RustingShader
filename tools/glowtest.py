# Render the glow halo (lib/glow.glsl) on a fake emission image, without Minecraft.
# Runs the same two steps as the game: tiles (composite1), then sum + tonemap (final).
# Usage: ~/.venv-aurora/bin/python tools/glowtest.py out.png [glow_strength]
import moderngl, numpy as np, pathlib, sys
from PIL import Image

root = pathlib.Path(__file__).resolve().parent.parent / "shaders"
glow = "#version 330\n#define texture2D texture\n#define texture2DLod textureLod\n" + (root / "lib/glow.glsl").read_text()
W, H = 1280, 720
strength = float(sys.argv[2]) if len(sys.argv) > 2 else 1.0

# fake scene: dark wall, a powered redstone line, a torch flame, a glowing block
emit = np.zeros((H, W, 3), "f4")
emit[360:363, 150:700] = (2.6, 0.18, 0.08)          # redstone dust line, 3 px
emit[250:262, 900:906] = (6.0, 3.6, 1.4)            # torch flame
emit[450:530, 950:1030] = (1.2, 0.08, 0.04)         # redstone block face
emit[200:210, 300:310] = (0.3, 2.0, 2.5)            # small cyan crystal
scene = np.full((H, W, 3), 0.02, "f4") + emit * 1.0

ctx = moderngl.create_standalone_context(backend="egl")
vs = "#version 330\nin vec2 p;out vec2 texcoord;void main(){texcoord=p*0.5+0.5;gl_Position=vec4(p,0,1);}"
tri = ctx.buffer(np.array([-1, -1, 3, -1, -1, 3], "f4"))

src = ctx.texture((W, H), 3, emit[::-1].tobytes(), dtype="f4")
src.build_mipmaps(); src.filter = (moderngl.LINEAR_MIPMAP_LINEAR, moderngl.LINEAR); src.repeat_x = src.repeat_y = False
tiles = ctx.texture((W, H), 4, dtype="f2"); tiles.repeat_x = tiles.repeat_y = False

p1 = ctx.program(vertex_shader=vs, fragment_shader=glow + """
uniform sampler2D src; uniform vec2 texel; in vec2 texcoord; out vec4 o;
void main(){ o = vec4(glowTiles(src, texcoord, texel), 1.0); }""")
p1["texel"].value = (1 / W, 1 / H)
ctx.framebuffer([tiles]).use(); src.use(0); p1["src"].value = 0
ctx.simple_vertex_array(p1, tri, "p").render()

sc = ctx.texture((W, H), 3, scene[::-1].tobytes(), dtype="f4")
p2 = ctx.program(vertex_shader=vs, fragment_shader=glow + """
uniform sampler2D tiles, scene; uniform vec2 screen; uniform float strength; in vec2 texcoord; out vec4 o;
vec3 aces(vec3 x){return clamp((x*(2.51*x+0.03))/(x*(2.43*x+0.59)+0.14),0.,1.);}
void main(){
    vec3 c = texture(scene, texcoord).rgb + glowAt(tiles, texcoord, screen) * strength;
    o = vec4(pow(aces(c), vec3(1.0/2.2)), 1.0);
}""")
tiles.use(0); sc.use(1); p2["tiles"].value = 0; p2["scene"].value = 1
p2["screen"].value = (W, H); p2["strength"].value = strength
fbo = ctx.simple_framebuffer((W, H)); fbo.use()
ctx.simple_vertex_array(p2, tri, "p").render()
Image.frombytes("RGB", (W, H), fbo.read()).transpose(Image.FLIP_TOP_BOTTOM).save(sys.argv[1])
