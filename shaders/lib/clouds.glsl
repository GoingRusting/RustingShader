float cloudDensity(vec3 p, int lod) {
    float h = (p.y - CLOUD_HEIGHT) / CLOUD_THICKNESS;
    if (h < 0.0 || h > 1.0) return 0.0;

    float t = frameTimeCounter * CLOUD_SPEED;
    p += vec3(t * 5.0, 0.0, t * 2.0);

    vec2 q = p.xz * 0.0035;
    float base = vnoise(q) * 0.55 + vnoise(q * 2.3 + 1.7) * 0.30 + vnoise(q * 5.3 - 3.1) * 0.15;

    float cover = CLOUD_COVERAGE + rainStrength * 0.3;
    float d = base - (1.0 - cover) - h * h * 0.3;
    d *= smoothstep(0.0, 0.1, h);
    if (d <= 0.0) return 0.0;

    vec3 r = p * 0.02;
    float det = 0.0, amp = 0.5;
    for (int i = 0; i < 3; i++) {
        if (i >= lod) break;
        det += vnoise3(r) * amp;
        r *= 2.3;
        amp *= 0.5;
    }
    d -= det * 0.18;
    return clamp(d * 5.0, 0.0, 1.0);
}

float cloudShadow(vec3 worldPos, vec3 lightDir) {
    float y = CLOUD_HEIGHT + CLOUD_THICKNESS * 0.3;
    vec3 p = worldPos + lightDir * max(y - worldPos.y, 0.0) / max(lightDir.y, 0.1);
    p.y = y;
    return exp(-cloudDensity(p, 0) * 3.0);
}

float cloudPhase(float cosT) {
    float a = (1.0 - 0.36) / pow(1.0 + 0.36 - 1.2 * cosT, 1.5);
    float b = (1.0 - 0.04) / pow(1.0 + 0.04 + 0.4 * cosT, 1.5);
    return mix(a, b, 0.4);
}

vec4 renderClouds(vec3 dir, float maxDist, vec3 lightDir, vec3 sunLight, vec3 ambient, float dither) {
    float camY = cameraPosition.y;
    float lo = CLOUD_HEIGHT, hi = CLOUD_HEIGHT + CLOUD_THICKNESS;
    if (abs(dir.y) < 0.001) return vec4(0.0, 0.0, 0.0, 1.0);

    float tA = (lo - camY) / dir.y, tB = (hi - camY) / dir.y;
    float t0 = max(min(tA, tB), 0.0);
    float t1 = min(max(tA, tB), maxDist);
    t1 = min(t1, t0 + CLOUD_THICKNESS * 6.0);
    if (t1 <= t0) return vec4(0.0, 0.0, 0.0, 1.0);

    float stepLen = (t1 - t0) / float(CLOUD_STEPS);
    float phase   = cloudPhase(dot(dir, lightDir));
    vec3  scatter = vec3(0.0);
    float trans   = 1.0;

    for (int i = 0; i < CLOUD_STEPS; i++) {
        vec3 p = cameraPosition + dir * (t0 + (float(i) + dither) * stepLen);
        float d = cloudDensity(p, 4);
        if (d <= 0.0) continue;

        float od = 0.0;
        for (int j = 1; j <= 4; j++) {
            float s = float(j * j) * 6.0;
            od += cloudDensity(p + lightDir * s, 1) * s * 0.5;
        }
        float h = (p.y - lo) / CLOUD_THICKNESS;
        vec3 sun = sunLight * (exp(-od * 0.10) + exp(-od * 0.025) * 0.3) * phase * 0.9;
        vec3 amb = ambient * (0.25 + 0.75 * h);
        float stepT = exp(-d * stepLen * 0.08);

        scatter += trans * (sun + amb) * (1.0 - stepT);
        trans *= stepT;
        if (trans < 0.02) break;
    }

    float fade = exp(-t0 * 0.0005);
    return vec4(scatter * fade, mix(1.0, trans, fade));
}
