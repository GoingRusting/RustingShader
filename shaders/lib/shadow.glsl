uniform sampler2D shadowtex0;

float getShadow(vec3 sp) {
    vec3 p = distortShadow(sp) * 0.5 + 0.5;
    if (any(lessThan(p, vec3(0.0))) || any(greaterThan(p, vec3(1.0)))) return 1.0;
    p.z -= 0.0002;

    float ang = ign(gl_FragCoord.xy) * 6.2831853;
    mat2 rot = mat2(cos(ang), sin(ang), -sin(ang), cos(ang));
    float texel = 1.0 / float(shadowMapResolution);

    float blocker = 0.0, found = 0.0;
    for (int i = 0; i < 6; i++) {
        float fi = float(i) + 0.5;
        vec2 off = rot * vec2(cos(fi * 2.4), sin(fi * 2.4)) * sqrt(fi / 6.0) * texel * 8.0;
        float z = texture2D(shadowtex0, p.xy + off).r;
        if (z < p.z) { blocker += z; found += 1.0; }
    }
    if (found == 0.0) return 1.0;

    float gap = p.z - blocker / found;
    float radius = texel * clamp(gap * 900.0 * SHADOW_SOFTNESS, 0.7, 10.0);

    float lit = 0.0;
    for (int i = 0; i < 12; i++) {
        float fi = float(i) + 0.5;
        vec2 off = vec2(cos(fi * 2.4), sin(fi * 2.4)) * sqrt(fi / 12.0);
        lit += step(p.z, texture2D(shadowtex0, p.xy + rot * off * radius).r);
    }
    lit /= 12.0;

    float edge = smoothstep(0.85, 1.0, max(abs(sp.x), abs(sp.y)));
    return mix(lit, 1.0, edge);
}

float getShadowFast(vec3 sp) {
    vec3 p = distortShadow(sp) * 0.5 + 0.5;
    if (any(lessThan(p, vec3(0.0))) || any(greaterThan(p, vec3(1.0)))) return 1.0;
    return step(p.z - 0.0006, texture2D(shadowtex0, p.xy).r);
}
