const float GLOW_PAD = 0.012;

vec2 glowTile(float lod) {
    if (lod < 1.5) return vec2(0.0);
    return vec2(0.5 - exp2(1.0 - lod) + (lod - 2.0) * GLOW_PAD, 0.5 + GLOW_PAD);
}

vec3 bicubic(sampler2D tex, vec2 uv, vec2 res, float lod) {
    vec2 st = uv * res - 0.5;
    vec2 i = floor(st), f = st - i;
    vec2 f2 = f * f, f3 = f2 * f;
    vec2 w0 = (-f3 + 3.0 * f2 - 3.0 * f + 1.0) / 6.0;
    vec2 w1 = (3.0 * f3 - 6.0 * f2 + 4.0) / 6.0;
    vec2 w2 = (-3.0 * f3 + 3.0 * f2 + 3.0 * f + 1.0) / 6.0;
    vec2 w3 = f3 / 6.0;
    vec2 g0 = w0 + w1, g1 = w2 + w3;
    vec2 h0 = (i - 0.5 + w1 / g0) / res;
    vec2 h1 = (i + 1.5 + w3 / g1) / res;
    return g0.y * (g0.x * texture2D(tex, vec2(h0.x, h0.y), lod).rgb + g1.x * texture2D(tex, vec2(h1.x, h0.y), lod).rgb)
         + g1.y * (g0.x * texture2D(tex, vec2(h0.x, h1.y), lod).rgb + g1.x * texture2D(tex, vec2(h1.x, h1.y), lod).rgb);
}

float glowW(int k, int n, float s2, float f) {
    float a = k <= n ? exp(-float(k * k) * s2) : 0.0;
    float b = k > -n ? exp(-float((k - 1) * (k - 1)) * s2) : 0.0;
    return mix(a, b, f);
}

vec2 glowPair(int k, int n, float s2, float f) {
    float a = glowW(k, n, s2, f), b = glowW(k + 1, n, s2, f);
    return vec2(a + b, float(k) + b / (a + b));
}

vec3 glowTiles(sampler2D src, vec2 uv, vec2 texel) {
    if (uv.y > 0.8) return vec3(0.0);
    for (int k = 1; k <= 8; k++) {
        float lod = float(k);
        float size = exp2(-lod);
        vec2 local = (uv - glowTile(lod)) / size;

        vec2 m = 3.0 * texel / size;
        if (any(lessThan(local, -m)) || any(greaterThan(local, 1.0 + m))) continue;

        float mip = min(lod, 3.0);
        vec2 step = texel * exp2(mip);
        int n = int(3.0 * exp2(lod - mip));
        float s2 = 2.0 / float(n * n);

        vec2 st = local / step - 0.5;
        vec2 base = floor(st);
        vec2 f = st - base;
        base += 0.5;
        vec3 sum = vec3(0.0);
        float wsum = 0.0;
        for (int y = -n; y <= n; y += 2) {
            vec2 wy = glowPair(y, n, s2, f.y);
            for (int x = -n; x <= n; x += 2) {
                vec2 wx = glowPair(x, n, s2, f.x);
                float w = wx.x * wy.x;
                sum += texture2DLod(src, (base + vec2(wx.y, wy.y)) * step, mip).rgb * w;
                wsum += w;
            }
        }
        return sum / wsum;
    }
    return vec3(0.0);
}

vec3 glowAt(sampler2D tiles, vec2 uv, vec2 screen) {
    vec3 glow = vec3(0.0);
    for (int k = 1; k <= 8; k++) {
        float lod = float(k);
        vec2 tuv = uv * exp2(-lod) + glowTile(lod);
        glow += bicubic(tiles, tuv, screen, 0.0) * min(0.04 + 0.04 * lod, 0.15);
    }

    return glow / (1.0 + dot(glow, vec3(0.2126, 0.7152, 0.0722)));
}
