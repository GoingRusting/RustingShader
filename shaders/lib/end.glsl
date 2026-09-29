vec3 endHoleDir() { return normalize(vec3(0.45, 0.3, -0.84)); }

float fbm3(vec3 p) {
    float s = 0.0, a = 0.5;
    for (int i = 0; i < 4; i++) {
        s += vnoise3(p) * a;
        p = p * 2.03 + vec3(1.7, 9.2, 3.1);
        a *= 0.5;
    }
    return s / 0.9375;
}

vec3 endSpace(vec3 d) {
#if END_STYLE == 0

    float deep = smoothstep(-0.7, 0.4, d.y);
    if (deep <= 0.0) return vec3(0.0);
#endif
    float t = frameTimeCounter * 0.004;
    vec3 q = d * 2.0;

    vec3 w = vec3(fbm3(q + t), fbm3(q + 5.2 - t), fbm3(q + 9.7));
    float n    = fbm3(q * 1.4 + w * 2.2);
    float dust = fbm3(q * 3.1 + w * 3.0 + 20.0);
    vec3 neb = mix(vec3(0.22, 0.04, 0.42), vec3(0.03, 0.28, 0.5), smoothstep(0.35, 0.65, w.x));
    neb = mix(neb, vec3(0.85, 0.18, 0.5), smoothstep(0.55, 0.75, w.y));
    float dens = smoothstep(0.4, 0.85, n) * (1.0 - smoothstep(0.45, 0.7, dust) * 0.9);
#if END_STYLE == 0

    vec3 col = vec3(0.75, 0.78, 0.9) * dens * dens * 0.025 * END_NEBULA * deep;
#else
    vec3 col = neb * dens * dens * 0.35 * END_NEBULA + vec3(0.002, 0.001, 0.004);
#endif

    for (int i = 0; i < 2; i++) {
        float scale = i == 0 ? 90.0 : 220.0;
        vec3 sp = d * scale;
        vec3 cell = floor(sp);
        float h = hash13(cell + float(i) * 13.0);
    #if END_STYLE == 0
        const float th = 0.996;
    #else
        const float th = 0.985;
    #endif
        if (h > th) {
            vec3 c = vec3(hash13(cell + 1.3), hash13(cell + 7.1), hash13(cell + 3.7)) - 0.5;
            vec3 f = fract(sp) - 0.5 - c * 0.6;
            float s = exp(-dot(f, f) * 50.0) * (h - th) / (1.0 - th);
            vec3 tint = mix(vec3(1.0, 0.75, 0.55), vec3(0.65, 0.8, 1.0), hash13(cell + 5.0));
        #if END_STYLE == 0
            tint = mix(vec3(0.9), tint, 0.3) * 0.25 * deep;
        #endif
            col += tint * s * (i == 0 ? 6.0 : 2.0) * (1.0 - dust * 0.7);
        }
    }
    return col;
}

vec3 diskGlow(float r, float ang, float side) {
    if (r < 1.3 || r > 7.0) return vec3(0.0);
    float t = frameTimeCounter * BH_SPIN;

    float a = ang + t * 1.2 / pow(r, 1.5) + log(r) * 2.5;
    float n = vnoise3(vec3(cos(a) * 3.0, sin(a) * 3.0, r * 2.5)) * 0.55
            + vnoise3(vec3(cos(a) * 9.0, sin(a) * 9.0, r * 9.0)) * 0.3
            + vnoise3(vec3(cos(a) * 20.0, sin(a) * 20.0, r * 30.0)) * 0.15;
    float lanes = 0.75 + 0.25 * sin(r * 18.0 + n * 9.0);
    float I = smoothstep(1.3, 1.7, r) * (1.0 - smoothstep(3.0, 7.0, r)) / (r * r) * 3.0;
    I *= (0.15 + 1.6 * n * n * n) * lanes;

    float x = smoothstep(1.5, 5.0, r);
    vec3 temp = mix(vec3(1.0, 0.92, 0.85), vec3(1.0, 0.42, 0.1), smoothstep(0.0, 0.5, x));
    temp = mix(temp, vec3(0.6, 0.08, 0.12), smoothstep(0.5, 1.0, x));

    float beam = pow(1.0 + 0.55 * side, 3.0);
    temp = mix(temp, vec3(0.75, 0.85, 1.0), max(side, 0.0) * 0.35 * (1.0 - x));
    return temp * I * beam * 8.0 * BH_BRIGHTNESS;
}

vec3 endSky(vec3 d) {
    vec3  bh   = endHoleDir();
    float R    = 0.08 * BH_SIZE;
    float cosA = dot(d, bh);
    float a    = acos(clamp(cosA, -1.0, 1.0));
    vec3  perp = d - bh * cosA;
    float pl   = length(perp);
    perp = pl > 1e-5 ? perp / pl : vec3(0.0, 1.0, 0.0);

    float rE = R * 1.7;
    float a2 = a - rE * rE / max(a, 1e-4);
    vec3 col = endSpace(bh * cos(a2) + perp * sin(a2));
    col *= smoothstep(R * 1.0, R * 1.15, a);

    float cosMax  = cos(min(R * 8.0, 3.14));
    float cosHalf = cos(min(R * 4.0, 3.14));
    if (cosA > cosMax) {

        vec3 u = normalize(cross(bh, vec3(0.15, 1.0, 0.05)));
        vec3 v = cross(u, bh);

        vec2 q = vec2(dot(perp, u), dot(perp, v)) * a / R;
        float tilt = 0.18;
        float rr = length(q);

        col += vec3(1.0, 0.8, 0.6) * exp(-pow((rr - 1.12) / 0.025, 2.0)) * 2.0 * BH_BRIGHTNESS;

        if (rr > 1.1) {
            float hr = 1.3 + (rr - 1.15) * 4.0;
            vec3 halo = diskGlow(hr, atan(q.y, q.x) * 1.0 + 1.3, q.x / rr * 0.6);
            col += halo * smoothstep(1.1, 1.25, rr) * (0.3 + 0.7 * abs(q.y) / rr) * 0.7;
        }

        vec2 dp = vec2(q.x, q.y / tilt);
        float r = length(dp);
        vec3 front = diskGlow(r, atan(dp.y, dp.x), dp.x / max(r, 1e-3));
        float behind = dp.y > 0.0 ? smoothstep(1.0, 1.15, rr) : 1.0;
        front *= behind;
        float cover = clamp(luminance(front) * 2.0, 0.0, 1.0);
        col = col * (1.0 - cover * 0.8) + front;

        col += vec3(0.5, 0.2, 0.35) * exp(-rr * 0.5) * 0.12 * BH_BRIGHTNESS * smoothstep(1.0, 1.15, rr) * smoothstep(cosMax, cosHalf, cosA);
    }
    return col;
}

vec3 endFog(vec3 d) {
    float g = max(dot(d, endHoleDir()), 0.0);
#if END_STYLE == 0
    return vec3(0.004, 0.004, 0.006) + vec3(0.5, 0.18, 0.08) * pow(g, 8.0) * 0.04 * BH_BRIGHTNESS;
#endif
    return vec3(0.012, 0.005, 0.022) + vec3(0.5, 0.18, 0.08) * pow(g, 8.0) * 0.1 * BH_BRIGHTNESS;
}
