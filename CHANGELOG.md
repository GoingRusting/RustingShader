# Changelog

## Unreleased

- Lighting reworked: sky light takes the color of the sky (blue day, warm sunset, grey rain, blue moonlight); torch light no longer counted twice and fades smoothly over all 15 light levels.

- Glow: separate emission buffer blurred into a colored halo (Glow screen in settings).
- Redstone glow, plus furnaces, candles, crystals, sculk, portal, ores, glowing mobs, eyes, beacon beams, particles, held items.
- Held light: a torch in hand lights the area around you.
- Glow rebuilt: emission blurred with a real Gaussian at 8 sizes (new composite1 pass), summed into a bright core with a long soft tail. No squares, no flicker.
- Redstone glow: one clean red.
- Rain: wet reflective ground, puddles with raindrop rings, denser ripples on water.

## 1.0.0 — 2026-09-28

First public release.

- Deferred lighting with PCSS soft shadows, colored torch light and emissive blocks.
- Water: waves, refraction, screen-space reflections, foam, caustics, Snell's window, underwater god rays.
- Volumetric clouds with cloud shadows, volumetric light, ground fog, aurora.
- Round phased moon, softer realistic rain.
- Bloom, auto exposure, lens flare, color grading, vignette.
- Nether support.
- End: lensed black hole with a Doppler-beamed accretion disk and photon ring, volumetric smoke, two styles (Empty and Colored).
