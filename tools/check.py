# Compile-check every program of the pack without starting Minecraft.
# Inlines Iris-style "/..." includes, then runs glslangValidator on each file.
# Usage: python3 tools/check.py        (needs glslangValidator: pacman -S glslang)
import re, subprocess, pathlib, sys, tempfile

root = pathlib.Path(__file__).resolve().parent.parent / "shaders"
out = pathlib.Path(tempfile.mkdtemp(prefix="aurora-check-"))

def expand(path):
    src = path.read_text()
    return re.sub(r'#include\s+"(/[^"]+)"', lambda m: expand(root / m.group(1)[1:]), src)

bad = 0
for f in sorted(list(root.glob("*.?sh")) + list(root.glob("world*/*.?sh"))):
    src = expand(f)
    first, rest = src.split("\n", 1)
    # Iris defines these itself; glslang does not know them
    src = first + "\n#define MC_RENDER_STAGE_STARS 5\n#define MC_RENDER_STAGE_SUN 3\n#define MC_RENDER_STAGE_MOON 4\n" + rest
    tmp = out / (f.parent.name + "_" + f.stem + ("." + ("vert" if f.suffix == ".vsh" else "frag")))
    tmp.write_text(src)
    r = subprocess.run(["glslangValidator", str(tmp)], capture_output=True, text=True)
    ok = r.returncode == 0
    bad += not ok
    print(("OK  " if ok else "ERR ") + str(f.relative_to(root)))
    if not ok:
        print(r.stdout)
print(f"\n{'all OK' if not bad else str(bad) + ' failed'}")
sys.exit(bad)
