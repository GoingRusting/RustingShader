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

vec4 moonColor(vec3 dir, vec3 moonDir, int phase) {
    if (dot(dir, moonDir) < 0.0) return vec4(0.0);
    vec3 mu = normalize(cross(vec3(0.0, 1.0, 0.0), moonDir));
    vec3 mv = cross(moonDir, mu);
    vec2 p = vec2(dot(dir, mu), dot(dir, mv)) / (0.03 * MOON_SIZE);
    float r = length(p);
    float ph = float(phase) / 8.0 * 6.2832;
    float full = 0.5 + 0.5 * cos(ph);
    vec3 glow = vec3(0.55, 0.65, 1.0) * (exp(-r * 0.8) * 0.08 + exp(-r * 0.15) * 0.01) * full * MOON_BRIGHTNESS;
    if (r >= 1.0) return vec4(glow, 0.0);

    vec3 s = vec3(p, sqrt(1.0 - r * r));

    vec3 ld = vec3(sin(ph), 0.0, cos(ph));
    float light = smoothstep(-0.03, 0.12, dot(s, ld));

    float maria = smoothstep(0.5, 0.68, vnoise3(s * 2.2 + 3.0) * 0.7 + vnoise3(s * 5.0 + 1.0) * 0.3);
    float alb = mix(0.95, 0.42, maria);

    for (int i = 0; i < 2; i++) {
        vec3 cs = s * (i == 0 ? 6.0 : 14.0);
        vec3 cell = floor(cs);
        vec3 c = vec3(hash13(cell), hash13(cell + 2.1), hash13(cell + 4.7)) * 0.4 + 0.3;
        float cd = length(fract(cs) - c) / (0.12 + 0.18 * hash13(cell + 9.0));
        if (hash13(cell + 6.0) > 0.45)
            alb *= 1.0 - 0.22 * smoothstep(0.95, 0.5, cd) + 0.2 * smoothstep(0.75, 0.95, cd) * smoothstep(1.3, 0.95, cd);
    }
    alb *= 0.85 + 0.3 * vnoise3(s * 30.0);
    float limb = 0.7 + 0.3 * s.z;
    vec3 col = vec3(1.0, 0.97, 0.92) * alb * limb * (light + 0.004) * MOON_BRIGHTNESS;
    return vec4(col, smoothstep(1.0, 0.97, r));
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
