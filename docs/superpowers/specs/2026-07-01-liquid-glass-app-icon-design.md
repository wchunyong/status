# Liquid Glass App Icon Design

## Summary

Design a macOS app icon for Status using a light Liquid Glass direction: a restrained silver-blue rounded square base with a central blue-green status pulse. The icon should feel native, calm, lightweight, and precise, matching Status as a menu bar system monitor for network, memory, CPU, fan speed, and temperature.

This spec covers the visual direction and production requirements for ROADMAP R-025. It does not implement the icon asset or package integration.

## Product Context

Status is a lightweight native macOS menu bar monitor. Its primary promise is low overhead, 24-hour stability, and clear real-time system state. The icon should communicate "system status at a glance" without looking like a heavy dashboard, terminal tool, or generic analytics product.

## Approved Direction

Use the **Light Liquid Glass Status Pulse** concept:

- A macOS-style rounded square base.
- A light silver-blue glass material with subtle depth.
- A central pulse line representing live system status.
- A blue-to-green accent on the pulse line.
- No text, no literal fan, no dense CPU/network/memory glyphs.

## Visual Principles

- **Native first**: The icon should look at home beside modern macOS apps.
- **Readable small**: At 32px and 16px, the pulse silhouette must remain recognizable.
- **Calm monitoring**: Avoid alarm colors, aggressive contrast, and busy chart details.
- **Lightweight**: Prefer one strong symbol over many metric references.
- **Future-proof**: The icon should work for the whole app, not only the current fan/temperature feature.

## Composition

Canvas:

- Master artwork: 1024 x 1024 px.
- Export through a macOS `.iconset` into `.icns`.
- Use the standard macOS rounded-square app-icon silhouette with enough internal padding for small sizes.

Base:

- Rounded square with approximately 22-24% corner radius.
- Light silver-blue glass body.
- Subtle top-left highlight and bottom-right depth shadow.
- Thin inner highlight border to suggest glass without turning into a noisy outline.

Symbol:

- Centered horizontal pulse line.
- The pulse should have 4-5 segments: quiet lead-in, one clean peak, one clean valley, and a stable exit.
- Stroke should be thick enough to survive downscaling.
- Rounded stroke caps and joins.
- Accent gradient from clear blue to soft green.
- Optional faint glow directly behind the pulse line, kept very subtle.

## Palette

Base palette:

- Silver-blue glass: near `#EEF5FF`, `#D9E8F6`, `#BFD3E7`.
- Shadow tint: cool gray-blue, not black.
- Highlight: white with low opacity.

Accent palette:

- Pulse blue: around `#3B82F6`.
- Pulse green: around `#31C48D`.
- Use the green sparingly so the icon remains calm and system-like.

Avoid:

- Purple/blue neon gradients.
- Red/orange warning colors.
- Dark dashboard backgrounds.
- Beige or brown palettes.
- Dense multi-color metric charts.

## Small-Size Rules

The icon must be checked at:

- 1024 px: App Store-style large rendering.
- 256 px: Finder and previews.
- 128 px: Launchpad-like contexts.
- 64 px: common UI thumbnails.
- 32 px and 16 px: small Finder/list contexts.

Small-size simplification:

- If the glow becomes muddy, remove or reduce it in smaller exports.
- If the pulse line becomes too thin, use a slightly thicker small-size variant.
- Do not add labels or extra symbols to compensate for small size.

## Asset Deliverables

Final deliverables:

- `assets/icon/StatusIcon-1024.png` or equivalent master export.
- `assets/icon/Status.iconset/` containing all required macOS sizes.
- `assets/icon/Status.icns`.

Required iconset filenames:

- `icon_16x16.png`
- `icon_16x16@2x.png`
- `icon_32x32.png`
- `icon_32x32@2x.png`
- `icon_128x128.png`
- `icon_128x128@2x.png`
- `icon_256x256.png`
- `icon_256x256@2x.png`
- `icon_512x512.png`
- `icon_512x512@2x.png`

## Packaging Integration

After the final icon is approved:

- Copy `Status.icns` into `build/Status.app/Contents/Resources/` during packaging.
- Add `CFBundleIconFile` with value `Status` to the generated `Info.plist`.
- Keep this inside `scripts/package.sh` until the project moves to a formal `.app` bundle / Xcode project in M7.

## Acceptance Criteria

- The icon is recognizable at 16px, 32px, and 64px.
- The pulse line reads as "live system status" without needing text.
- The visual tone is light, native, and calm.
- The icon does not rely on any external network-loaded asset.
- The packaged local `.app` displays the icon in Finder after packaging.
- `iconutil -c icns` succeeds for the `.iconset`.
- `scripts/package.sh` still produces a valid ad-hoc signed local app after integration.

## Open Decisions

- Whether the master artwork is created manually in a design tool, generated as bitmap artwork, or built from vector source.
- Whether to keep separate small-size variants if downscaling the master makes the pulse too soft.
