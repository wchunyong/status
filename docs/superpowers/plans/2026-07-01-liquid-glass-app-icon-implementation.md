# Liquid Glass App Icon Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and package the approved light Liquid Glass Status app icon.

**Architecture:** Keep the icon as project-local assets under `assets/icon/`. Generate a 1024px master PNG, derive the required macOS `.iconset`, convert it to `Status.icns`, and teach `scripts/package.sh` to copy the icon and set `CFBundleIconFile`.

**Tech Stack:** Built-in image generation, macOS `sips`, `iconutil`, Bash packaging script, SwiftPM release build.

---

### Task 1: Generate Master Icon Asset

**Files:**
- Create: `assets/icon/StatusIcon-1024.png`

- [ ] **Step 1: Generate the master artwork**

Use built-in image generation with this prompt:

```text
Use case: logo-brand
Asset type: macOS app icon master image, 1024 x 1024
Primary request: Create a polished macOS app icon for an app named Status, a lightweight system monitor.
Subject: a light Liquid Glass rounded-square icon with a centered live status pulse line.
Style/medium: high-quality macOS app icon, refined 3D-rendered glass, native Apple-like polish, no text.
Composition/framing: centered rounded-square app icon occupying most of the canvas, generous padding, centered horizontal pulse line with one clean peak and one clean valley.
Lighting/mood: calm, precise, soft top-left highlight, subtle bottom-right depth shadow.
Color palette: silver-blue glass base near #EEF5FF, #D9E8F6, #BFD3E7; pulse accent transitions from #3B82F6 blue to #31C48D green.
Materials/textures: translucent frosted glass, subtle inner highlight edge, very subtle glow behind pulse line.
Constraints: no text, no letters, no numbers, no fan symbol, no dense charts, no real dashboard UI, no warning colors, no watermark. The pulse silhouette must stay readable at small sizes.
Avoid: purple neon, dark dashboard background, beige/brown palette, busy metric panels, realistic hardware, app screenshots.
```

- [ ] **Step 2: Save the selected output**

Copy or move the generated image into:

```bash
mkdir -p assets/icon
cp <generated-image-path> assets/icon/StatusIcon-1024.png
```

- [ ] **Step 3: Inspect the saved image**

Run:

```bash
file assets/icon/StatusIcon-1024.png
sips -g pixelWidth -g pixelHeight assets/icon/StatusIcon-1024.png
```

Expected:

- PNG image.
- Width and height are 1024px, or an image that can be safely normalized to 1024px before Task 2.

### Task 2: Build macOS Iconset and ICNS

**Files:**
- Create: `assets/icon/Status.iconset/`
- Create: `assets/icon/Status.icns`

- [ ] **Step 1: Generate iconset sizes**

Run:

```bash
rm -rf assets/icon/Status.iconset
mkdir -p assets/icon/Status.iconset
sips -z 16 16 assets/icon/StatusIcon-1024.png --out assets/icon/Status.iconset/icon_16x16.png
sips -z 32 32 assets/icon/StatusIcon-1024.png --out assets/icon/Status.iconset/icon_16x16@2x.png
sips -z 32 32 assets/icon/StatusIcon-1024.png --out assets/icon/Status.iconset/icon_32x32.png
sips -z 64 64 assets/icon/StatusIcon-1024.png --out assets/icon/Status.iconset/icon_32x32@2x.png
sips -z 128 128 assets/icon/StatusIcon-1024.png --out assets/icon/Status.iconset/icon_128x128.png
sips -z 256 256 assets/icon/StatusIcon-1024.png --out assets/icon/Status.iconset/icon_128x128@2x.png
sips -z 256 256 assets/icon/StatusIcon-1024.png --out assets/icon/Status.iconset/icon_256x256.png
sips -z 512 512 assets/icon/StatusIcon-1024.png --out assets/icon/Status.iconset/icon_256x256@2x.png
sips -z 512 512 assets/icon/StatusIcon-1024.png --out assets/icon/Status.iconset/icon_512x512.png
sips -z 1024 1024 assets/icon/StatusIcon-1024.png --out assets/icon/Status.iconset/icon_512x512@2x.png
```

- [ ] **Step 2: Convert iconset to icns**

Run:

```bash
iconutil -c icns assets/icon/Status.iconset -o assets/icon/Status.icns
```

Expected:

- `assets/icon/Status.icns` exists and is non-empty.

### Task 3: Integrate Icon Into Local Packaging

**Files:**
- Modify: `scripts/package.sh`

- [ ] **Step 1: Update package script**

Add an icon asset variable near the existing bundle constants:

```bash
ICON="assets/icon/Status.icns"
```

After creating `Contents/Resources`, copy the icon when present:

```bash
if [[ -f "$ICON" ]]; then
  cp "$ICON" "$APP/Contents/Resources/Status.icns"
else
  echo "⚠️ missing icon: $ICON"
fi
```

Add this plist entry:

```xml
  <key>CFBundleIconFile</key><string>Status</string>
```

- [ ] **Step 2: Package and verify**

Run:

```bash
scripts/package.sh
test -f build/Status.app/Contents/Resources/Status.icns
plutil -p build/Status.app/Contents/Info.plist | rg CFBundleIconFile
codesign --verify --deep --strict --verbose=2 build/Status.app
```

Expected:

- Package succeeds.
- `Status.icns` is inside the app bundle.
- `CFBundleIconFile` is set to `Status`.
- Codesign verification passes.

### Task 4: Final Gate and Review

**Files:**
- Review all modified files.

- [ ] **Step 1: Run full gate**

Run:

```bash
scripts/gate.sh
```

Expected:

- SwiftLint: 0 violations.
- SwiftFormat: 0 files require formatting.
- `swift build`: passes.
- `swift test`: all tests pass.

- [ ] **Step 2: Review git diff**

Run:

```bash
git status --short --branch
git diff --stat
```

Expected:

- Changes are limited to icon assets, `scripts/package.sh`, and implementation docs if this plan is committed.

- [ ] **Step 3: Commit implementation**

Run:

```bash
git add assets/icon scripts/package.sh docs/superpowers/plans/2026-07-01-liquid-glass-app-icon-implementation.md
git commit -m "feat(icon): add liquid glass app icon"
```
