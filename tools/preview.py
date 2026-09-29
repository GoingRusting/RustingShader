# Render the End sky (lib/end.glsl) to a PNG on the GPU, without Minecraft.
# Setup once:  python3 -m venv ~/.venv-aurora && ~/.venv-aurora/bin/pip install moderngl numpy pillow
# Usage:       ~/.venv-aurora/bin/python tools/preview.py out.png [yaw] [pitch] [fov] [time]
#   yaw/pitch: radians away from the black hole (0 0 = looking straight at it)
import moderngl, numpy as np, re, sys, pathlib
from PIL import Image

root = pathlib.Path(__file__).resolve().parent.parent / "shaders"
def expand(p): return re.sub(r'#include\s+"(/[^"]+)"', lambda m: expand(root / m.group(1)[1:]), p.read_text())

# settings + the noise helpers from common.glsl + end.glsl, with the Iris uniforms faked
lib = expand(root / "lib/settings.glsl") + "\nuniform float frameTimeCounter;\n"
common = (root / "lib/common.glsl").read_text().split("float ign", 1)[1]
common = "vec3 toLinear(vec3 c){return pow(c,vec3(2.2));}\nfloat luminance(vec3 c){return dot(c,vec3(0.2126,0.7152,0.0722));}\nfloat ign" + common
common = re.sub(r'uniform [^;]+;', '', common)
common = "mat4 gbufferModelViewInverse = mat4(1.0); vec3 sunPosition = vec3(0,1,0); float rainStrength = 0.0;\n" + common
fs = "#version 330\n" + lib + common + (root / "lib/end.glsl").read_text() + """
uniform vec2 res; uniform vec3 fwd; uniform float fov; out vec4 o;
vec3 aces(vec3 x){return clamp((x*(2.51*x+0.03))/(x*(2.43*x+0.59)+0.14),0.,1.);}
void main(){
    vec2 uv = (gl_FragCoord.xy / res * 2.0 - 1.0) * vec2(res.x / res.y, 1.0) * tan(fov * 0.5);
    vec3 f = normalize(fwd), r = normalize(cross(f, vec3(0,1,0))), u = cross(r, f);
    vec3 c = endSky(normalize(f + uv.x * r + uv.y * u));
    o = vec4(pow(aces(c), vec3(1.0 / 2.2)), 1.0);
}"""

args = [float(x) for x in sys.argv[2:6]] + [0.0, 0.0, 70.0, 10.0][len(sys.argv) - 2:]
yaw, pitch, fov, t = args[:4]
ctx = moderngl.create_standalone_context(backend="egl")
prog = ctx.program(vertex_shader="#version 330\nin vec2 p;void main(){gl_Position=vec4(p,0,1);}", fragment_shader=fs)
W, H = 1280, 720
vao = ctx.simple_vertex_array(prog, ctx.buffer(np.array([-1, -1, 3, -1, -1, 3], "f4")), "p")
fbo = ctx.simple_framebuffer((W, H)); fbo.use()
bh = np.array([0.45, 0.3, -0.84]); bh /= np.linalg.norm(bh)  # keep in sync with endHoleDir()
ang = np.arctan2(bh[0], -bh[2]) + yaw; el = np.arcsin(bh[1]) + pitch
prog["fwd"].value = (np.sin(ang) * np.cos(el), np.sin(el), -np.cos(ang) * np.cos(el))
prog["res"].value = (W, H); prog["fov"].value = np.radians(fov)
if "frameTimeCounter" in prog: prog["frameTimeCounter"].value = t
vao.render()
Image.frombytes("RGB", (W, H), fbo.read()).transpose(Image.FLIP_TOP_BOTTOM).save(sys.argv[1])
print("saved", sys.argv[1])
