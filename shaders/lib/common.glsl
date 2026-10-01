uniform mat4 gbufferModelViewInverse;
uniform vec3 sunPosition;
uniform float rainStrength;
uniform float frameTimeCounter;

vec3 toLinear(vec3 c) { return pow(c, vec3(2.2)); }

float luminance(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }

float ign(vec2 p) { return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715)))); }

vec3 distortShadow(vec3 p) {
    float f = mix(1.0, length(p.xy), SHADOW_DISTORT);
    return vec3(p.xy / f, p.z * 0.5);
}

vec3 waveOffset(vec3 worldPos, float id, bool isTop) {
    float t = frameTimeCounter * WAVE_SPEED;
    float a = 0.0;
    if (id == 10001.0 && isTop) a = 0.10;
    else if (id == 10004.0)     a = 0.07;
    else if (id == 10002.0)     a = 0.035;
    if (a == 0.0) return vec3(0.0);
    a *= WAVE_AMPLITUDE * (1.0 + rainStrength);
    float wx = sin(t * 1.7 + worldPos.x * 0.6 + worldPos.z * 0.3) + sin(t * 2.9 + worldPos.z * 1.1) * 0.5;
    float wz = sin(t * 1.3 + worldPos.z * 0.7 + worldPos.x * 0.2) + sin(t * 3.3 + worldPos.x * 0.9) * 0.5;
    return vec3(wx, wx * wz * 0.3, wz) * a;
}

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}
float hash13(vec3 p3) {
    p3 = fract(p3 * 0.1031);
    p3 += dot(p3, p3.zyx + 31.32);
    return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x),
               mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x), f.y);
}
float vnoise3(vec3 p) {
    vec3 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(mix(hash13(i),                   hash13(i + vec3(1.0, 0.0, 0.0)), f.x),
                   mix(hash13(i + vec3(0.0, 1.0, 0.0)), hash13(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
               mix(mix(hash13(i + vec3(0.0, 0.0, 1.0)), hash13(i + vec3(1.0, 0.0, 1.0)), f.x),
                   mix(hash13(i + vec3(0.0, 1.0, 1.0)), hash13(i + vec3(1.0, 1.0, 1.0)), f.x), f.y), f.z);
}

float waterHeight(vec2 p, float detail) {
    float t = frameTimeCounter * WATER_SPEED;
    mat2 r = mat2(0.8, -0.6, 0.6, 0.8);
    float h = 0.0;
    h += vnoise(p * 0.35 + vec2(t * 0.25, t * 0.10)) * 1.00;
    h += vnoise(r * p * 0.9 - vec2(t * 0.30, t * 0.45)) * 0.50;
    h += vnoise(r * r * p * 2.1 + vec2(t * 0.60, -t * 0.35)) * 0.22 * detail;
    h += vnoise(r * p * 4.7 - vec2(t * 1.1, t * 0.8)) * 0.08 * detail * detail;
    return h;
}

vec2 rainRipples(vec2 p) {
    vec2 slope = vec2(0.0);
    for (int i = 0; i < 3; i++) {
        vec2 q = p * 2.2 + float(i) * 17.3;
        vec2 cell = floor(q);
        float h = hash12(cell);
        float t = fract(frameTimeCounter * 0.8 + h);
        vec2 center = (vec2(hash12(cell + 3.1), hash12(cell + 7.7)) - 0.5) * 0.5;
        vec2 d = fract(q) - 0.5 - center;
        float r = length(d), front = t * 0.5;
        float ring = sin((r - front) * 40.0) * (1.0 - t) * (1.0 - t) * (1.0 - smoothstep(0.0, 0.06, abs(r - front)));
        slope += d / max(r, 0.001) * ring;
    }
    return slope;
}

vec3 waterNormal(vec2 p, float dist) {
    float detail = 1.0 / (1.0 + dist * 0.05);
    float e = 0.05 + dist * 0.004;
    float k = 0.12 * WATER_WAVE_HEIGHT / (1.0 + dist * 0.03);
    float h0 = waterHeight(p, detail);
    float hx = waterHeight(p + vec2(e, 0.0), detail);
    float hz = waterHeight(p + vec2(0.0, e), detail);
    vec2 n = vec2(h0 - hx, h0 - hz) / e * k;
    if (rainStrength > 0.0) n += rainRipples(p) * 0.5 * rainStrength * detail;
    return normalize(vec3(n.x, 1.0, n.y));
}

float caustics(vec2 p) {
    float t = frameTimeCounter * WATER_SPEED;
    float a = 1.0 - abs(vnoise(p * 1.3 + vec2(t * 0.5, t * 0.3)) * 2.0 - 1.0);
    float b = 1.0 - abs(vnoise(p * 1.7 - vec2(t * 0.4, -t * 0.6) + 3.7) * 2.0 - 1.0);
    return pow(a * b, 3.0) * 2.5;
}

vec3 sunDirWorld()  { return normalize(mat3(gbufferModelViewInverse) * sunPosition + vec3(0.0, 1e-4, 0.0)); }

float dayFactor(vec3 sunDir) { return smoothstep(-0.12, 0.18, sunDir.y); }

float sunsetFactor(vec3 sunDir) { return 1.0 - smoothstep(0.0, 0.35, abs(sunDir.y + 0.03)); }

vec3 directLightColor(vec3 sunDir) {
    float day = dayFactor(sunDir);
    vec3 noon   = vec3(1.00, 0.93, 0.82) * SUN_STRENGTH;
    vec3 sunset = vec3(1.00, 0.48, 0.20) * SUN_STRENGTH * 0.8;
    vec3 moon   = vec3(0.35, 0.50, 0.90) * MOON_STRENGTH;
    vec3 c = mix(noon, sunset, sunsetFactor(sunDir));
    c = mix(moon, c, day);

    c *= smoothstep(0.0, 0.08, abs(sunDir.y));
    return c * (1.0 - rainStrength * 0.85);
}

float moonBasin(vec2 p, vec2 center, vec2 extent, float edgeNoise) {
    float dist = length((p - center) / extent);
    return 1.0 - smoothstep(0.72, 1.12, dist + edgeNoise);
}

// Height and analytic slopes: raised rims, recessed bowls and central peaks.
vec3 moonCrater(vec2 offset, float radius) {
    float dist = length(offset);
    float r = dist / radius;
    if (r > 1.4) return vec3(0.0);
    float t = clamp((r - 0.55) / 0.45, 0.0, 1.0);
    float bowl = 1.0 - t * t * (3.0 - 2.0 * t);
    float rim = exp(-pow((r - 1.0) / 0.13, 2.0));
    float peak = exp(-r * r * 65.0);
    float height = radius * (-0.12 * bowl + 0.065 * rim + 0.045 * peak);
    float slope = 0.12 * 6.0 * t * (1.0 - t) / 0.45
                - 0.13 * (r - 1.0) / (0.13 * 0.13) * rim
                - 0.09 * 65.0 * r * peak;
    return vec3(height, offset / max(dist, 0.0001) * slope);
}

vec4 moonColor(vec3 dir, vec3 moonDir, int phase) {
    if (dot(dir, moonDir) < 0.0) return vec4(0.0);
    // A stable tangent frame also handles a moon directly overhead.
    vec3 axis = abs(moonDir.y) > 0.99 ? vec3(0.0, 0.0, 1.0) : vec3(0.0, 1.0, 0.0);
    vec3 mu = normalize(cross(axis, moonDir));
    vec3 mv = cross(moonDir, mu);
    vec2 p = vec2(dot(dir, mu), dot(dir, mv)) / (0.03 * MOON_SIZE);
    float r = length(p);
    float ph = float(phase) / 8.0 * 6.2831853;
    float full = 0.5 + 0.5 * cos(ph);
    float halo = exp(-max(r - 1.0, 0.0) * 7.0) * 0.022
               + exp(-r * r * 0.45) * 0.012;
    vec3 glow = vec3(0.62, 0.73, 1.0) * halo * full * MOON_BRIGHTNESS;
    if (r >= 1.0) return vec4(glow, 0.0);

    vec3 s = vec3(p, sqrt(max(1.0 - r * r, 0.0)));
    vec3 ld = vec3(sin(ph), 0.0, cos(ph));

    // Connected dark seas with rough coastlines and brighter southern highlands.
    float edge = (vnoise3(s * 12.0 + 3.7) - 0.5) * 0.38;
    vec2 basinPos = p + (vec2(vnoise(p * 7.0 + 2.3), vnoise(p * 7.0 - 4.7)) - 0.5) * 0.10;
    float maria = moonBasin(basinPos, vec2(-0.48, 0.05), vec2(0.30, 0.47), edge);
    maria = max(maria, moonBasin(basinPos, vec2(-0.24, 0.40), vec2(0.28, 0.30), edge));
    maria = max(maria, moonBasin(basinPos, vec2(0.20, 0.25), vec2(0.19, 0.23), edge));
    maria = max(maria, moonBasin(basinPos, vec2(0.36, 0.02), vec2(0.24, 0.22), edge));
    maria = max(maria, moonBasin(basinPos, vec2(0.53, -0.20), vec2(0.17, 0.24), edge));
    float alb = mix(0.72, 0.25, maria);
    alb *= 0.86 + 0.24 * vnoise3(s * 24.0 + 1.3);
    alb *= 0.94 + 0.12 * vnoise3(s * 85.0);

    vec3 terrain = vec3(0.0);
    for (int i = 0; i < 2; i++) {
        float scale = i == 0 ? 5.0 : 13.0;
        vec2 cell = floor(p * scale);
        for (int y = -1; y <= 1; y++) {
            for (int x = -1; x <= 1; x++) {
                vec2 id = cell + vec2(float(x), float(y));
                float seed = hash12(id + float(i) * 31.7);
                if (seed < 0.32) continue;
                vec2 center = id + vec2(hash12(id + 4.1), hash12(id + 9.3));
                vec3 crater = moonCrater(p * scale - center, mix(0.16, 0.42, seed));
                terrain += vec3(crater.x / scale, crater.yz) * mix(1.0, 0.45, maria);
            }
        }
    }

    // A prominent southern crater and its faint, irregular ejecta rays.
    vec2 rayPos = p - vec2(0.12, -0.60);
    terrain += moonCrater(rayPos, 0.075);
    float angle = atan(rayPos.y, rayPos.x);
    float rays = pow(0.5 + 0.5 * sin(angle * 19.0 + vnoise(p * 16.0) * 4.0), 10.0);
    rays *= exp(-length(rayPos) * 3.5) * smoothstep(0.075, 0.13, length(rayPos));
    alb *= 1.0 + rays * 0.30;
    alb *= clamp(1.0 + terrain.x * 5.0, 0.80, 1.15);

    vec3 normal = normalize(s - vec3(terrain.yz, 0.0) * 0.45);
    // Ease illumination across the terminator instead of cutting it off.
    float normalLight = dot(normal, ld);
    float incidence = 0.5 * (normalLight + sqrt(normalLight * normalLight + 0.0064));
    float lit = smoothstep(-0.18, 0.24, dot(s, ld));
    float diffuse = incidence / max(incidence + s.z, 0.025);
    float light = lit * (0.55 * incidence + 0.80 * diffuse);
    // Keep the shadowed terrain faintly readable through every phase.
    float earthshine = 0.025 + 0.025 * (1.0 - full);
    vec3 tint = mix(vec3(1.0, 0.97, 0.92), vec3(0.83, 0.88, 0.96), maria * 0.45);
    vec3 col = tint * alb * light + vec3(0.56, 0.66, 0.88) * alb * earthshine;
    col *= MOON_BRIGHTNESS * (0.88 + 0.12 * s.z);
    float mask = 1.0 - smoothstep(0.994, 1.0, r);
    return vec4(col * mask + glow * (1.0 - mask), mask);
}

vec3 aurora(vec3 dir, vec3 sunDir) {
    float night = 1.0 - dayFactor(sunDir);
    if (dir.y <= 0.0 || night <= 0.0 || rainStrength >= 1.0) return vec3(0.0);
    float t = frameTimeCounter * 0.03;
    vec3 col = vec3(0.0);
    for (int i = 0; i < 10; i++) {
        float fi = float(i) / 10.0;

        vec2 uv = dir.xz / (dir.y + 0.15 + fi * 0.12) * 1.5;
        float n = vnoise(uv * vec2(0.6, 1.4) + vec2(t, -t * 0.5)) + vnoise(uv * 2.3 - t * 1.7) * 0.4;
        float ribbon = pow(1.0 - abs(n / 1.4 * 2.0 - 1.0), 12.0);
        vec3 c = mix(vec3(0.1, 1.0, 0.45), vec3(0.55, 0.15, 1.0), fi * fi);
        col += c * ribbon * (1.0 - fi);
    }
    return col * 0.05 * AURORA_STRENGTH * night * smoothstep(0.0, 0.3, dir.y) * (1.0 - rainStrength);
}

vec3 skyColor(vec3 dir, vec3 sunDir) {
    float day    = dayFactor(sunDir);
    float sunset = sunsetFactor(sunDir);
    float up     = clamp(dir.y, 0.0, 1.0);
    float sunDot = max(dot(dir, sunDir), 0.0);

    vec3 zenith  = mix(vec3(0.002, 0.004, 0.014), vec3(0.08, 0.22, 0.75), day);
    vec3 horizon = mix(vec3(0.012, 0.02, 0.05),   vec3(0.55, 0.72, 0.95), day);

    vec3 sunsetLow = mix(vec3(1.0, 0.30, 0.08), vec3(1.0, 0.55, 0.25), up * 4.0);
    horizon = mix(horizon, sunsetLow, sunset * (0.35 + 0.65 * sunDot * sunDot));
    zenith  = mix(zenith, vec3(0.20, 0.16, 0.42), sunset * 0.45);

    vec3 sky = mix(horizon, zenith, pow(up, 0.4));
    sky += horizon * exp(-up * 18.0) * 0.25;
    sky *= 1.0 - smoothstep(0.0, 0.4, -dir.y) * 0.6;

    sky += directLightColor(sunDir) * (pow(sunDot, 5.0) * 0.18 + pow(sunDot, 48.0) * 0.5 + pow(sunDot, 600.0) * 2.0) * day;

    sky = mix(sky, vec3(luminance(sky)) * 0.6, rainStrength * 0.8);
    return sky;
}
