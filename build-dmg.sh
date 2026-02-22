#!/bin/bash
set -e

APP_NAME="Cleankeun"
BUNDLE_ID="com.cleankeun.pro"
VERSION="1.1.1"

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/.build/release"
DIST_DIR="$PROJECT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
DMG_PATH="$DIST_DIR/$APP_NAME.dmg"
ENTITLEMENTS="$DIST_DIR/Cleankeun.entitlements"

echo "=== Building $APP_NAME v$VERSION Release ==="

# 1. Build release binary
echo "[1/6] Building release binary..."
cd "$PROJECT_DIR"
swift build -c release 2>&1
BINARY="$BUILD_DIR/$APP_NAME"

if [ ! -f "$BINARY" ]; then
    echo "ERROR: Release binary not found at $BINARY"
    exit 1
fi
echo "  Binary: $(du -h "$BINARY" | cut -f1) at $BINARY"

# 2. Create .app bundle structure
echo "[2/6] Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy binary
cp "$BINARY" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod 755 "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Create Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>Cleankeun Pro</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>2</string>
    <key>LSMinimumSystemVersion</key>
    <string>26.0</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSUIElement</key>
    <false/>
    <key>NSSupportsAutomaticTermination</key>
    <true/>
    <key>NSSupportsSuddenTermination</key>
    <false/>
</dict>
</plist>
PLIST

# Create PkgInfo
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

echo "  App bundle created at $APP_BUNDLE"

# 3. Generate app icon using compiled Swift (no PyObjC dependency)
echo "[3/6] Generating app icon..."
ICON_GENERATOR="$DIST_DIR/generate_icon.swift"
ICONSET_DIR="$DIST_DIR/AppIcon.iconset"
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

cat > "$ICON_GENERATOR" << 'SWIFTEOF'
import AppKit
import Foundation

// Cleankeun Pro App Icon Generator
// Design: Blue gradient rounded rect + sweep arc + sparkles
// Matches the CleankeunLogo.swift SwiftUI view

func createIcon(size: Int) -> NSBitmapImageRep {
    let s = CGFloat(size)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .calibratedRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!

    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx
    let cg = ctx.cgContext

    let cornerRadius = s * 0.22

    // --- Background: blue gradient rounded rect ---
    let bgPath = CGPath(roundedRect: CGRect(x: 0, y: 0, width: s, height: s),
                        cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    cg.addPath(bgPath)
    cg.clip()

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    // Brand gradient: dark blue bottom -> light blue top
    let gradientColors = [
        CGColor(colorSpace: colorSpace, components: [0.0, 0.30, 0.80, 1.0])!,   // brand-dark
        CGColor(colorSpace: colorSpace, components: [0.10, 0.55, 1.0, 1.0])!,    // brand
        CGColor(colorSpace: colorSpace, components: [0.30, 0.66, 1.0, 1.0])!,    // brand-light
    ] as CFArray
    let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: [0.0, 0.5, 1.0])!
    cg.drawLinearGradient(gradient,
                          start: CGPoint(x: s * 0.5, y: 0),
                          end: CGPoint(x: s * 0.5, y: s),
                          options: [])

    // --- Subtle top highlight for depth ---
    cg.saveGState()
    let overlayColors = [
        CGColor(colorSpace: colorSpace, components: [1.0, 1.0, 1.0, 0.12])!,
        CGColor(colorSpace: colorSpace, components: [1.0, 1.0, 1.0, 0.0])!,
    ] as CFArray
    let overlayGrad = CGGradient(colorsSpace: colorSpace, colors: overlayColors, locations: [0.0, 1.0])!
    cg.drawLinearGradient(overlayGrad,
                          start: CGPoint(x: s * 0.5, y: s),
                          end: CGPoint(x: s * 0.5, y: s * 0.5),
                          options: [])
    cg.restoreGState()

    // --- Sweep / clean arc ---
    // Matching CleankeunLogo.swift: Circle().trim(from: 0.2, to: 0.9), rotated -45°
    let cx = s * 0.5
    let cy = s * 0.5
    let arcRadius = s * 0.28
    let lineWidth = s * 0.065

    // SwiftUI angles: 0 = top (12 o'clock), clockwise
    // CG angles: 0 = right (3 o'clock), counterclockwise
    // trim(from: 0.2, to: 0.9) = 252° arc
    // With -45° rotation
    let startAngle = CGFloat.pi / 2 - (0.2 * 2 * .pi) + (CGFloat.pi / 4)
    let endAngle = CGFloat.pi / 2 - (0.9 * 2 * .pi) + (CGFloat.pi / 4)

    cg.saveGState()
    cg.setStrokeColor(CGColor(colorSpace: colorSpace, components: [1.0, 1.0, 1.0, 0.9])!)
    cg.setLineWidth(lineWidth)
    cg.setLineCap(.round)
    cg.addArc(center: CGPoint(x: cx, y: cy), radius: arcRadius,
              startAngle: startAngle, endAngle: endAngle, clockwise: true)
    cg.strokePath()

    // Faded tail effect
    cg.setStrokeColor(CGColor(colorSpace: colorSpace, components: [1.0, 1.0, 1.0, 0.3])!)
    cg.setLineWidth(lineWidth * 1.5)
    let fadeStart = startAngle - (startAngle - endAngle) * 0.6
    cg.addArc(center: CGPoint(x: cx, y: cy), radius: arcRadius,
              startAngle: fadeStart, endAngle: endAngle, clockwise: true)
    cg.strokePath()
    cg.restoreGState()

    // --- Large sparkle ---
    drawSparkle(cg: cg, cx: cx - s * 0.12, cy: cy + s * 0.12, size: s * 0.20, color: colorSpace)

    // --- Small sparkle ---
    drawSparkle(cg: cg, cx: cx + s * 0.18, cy: cy - s * 0.08, size: s * 0.10, color: colorSpace)

    // --- Tiny sparkle ---
    drawSparkle(cg: cg, cx: cx + s * 0.05, cy: cy + s * 0.25, size: s * 0.06, color: colorSpace, alpha: 0.6)

    ctx.flushGraphics()
    NSGraphicsContext.current = nil
    return rep
}

func drawSparkle(cg: CGContext, cx: CGFloat, cy: CGFloat, size: CGFloat, color: CGColorSpace, alpha: CGFloat = 0.95) {
    let r = size / 2
    let inner = r * 0.3
    cg.saveGState()
    cg.setFillColor(CGColor(colorSpace: color, components: [1.0, 1.0, 1.0, alpha])!)

    let path = CGMutablePath()
    path.move(to: CGPoint(x: cx, y: cy + r))
    path.addQuadCurve(to: CGPoint(x: cx + r, y: cy),
                      control: CGPoint(x: cx + inner * 0.4, y: cy + inner * 0.4))
    path.addQuadCurve(to: CGPoint(x: cx, y: cy - r),
                      control: CGPoint(x: cx + inner * 0.4, y: cy - inner * 0.4))
    path.addQuadCurve(to: CGPoint(x: cx - r, y: cy),
                      control: CGPoint(x: cx - inner * 0.4, y: cy - inner * 0.4))
    path.addQuadCurve(to: CGPoint(x: cx, y: cy + r),
                      control: CGPoint(x: cx - inner * 0.4, y: cy + inner * 0.4))
    path.closeSubpath()

    cg.addPath(path)
    cg.fillPath()

    // Glow
    cg.setShadow(offset: .zero, blur: size * 0.4,
                 color: CGColor(colorSpace: color, components: [1.0, 1.0, 1.0, alpha * 0.5])!)
    cg.addPath(path)
    cg.fillPath()

    cg.restoreGState()
}

// --- Main ---
let distDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "dist"
let iconsetDir = "\(distDir)/AppIcon.iconset"

let sizes: [(name: String, px: Int)] = [
    ("icon_16x16", 16),
    ("icon_16x16@2x", 32),
    ("icon_32x32", 32),
    ("icon_32x32@2x", 64),
    ("icon_128x128", 128),
    ("icon_128x128@2x", 256),
    ("icon_256x256", 256),
    ("icon_256x256@2x", 512),
    ("icon_512x512", 512),
    ("icon_512x512@2x", 1024),
]

for entry in sizes {
    let rep = createIcon(size: entry.px)
    let data = rep.representation(using: .png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: "\(iconsetDir)/\(entry.name).png"))
}

print("  Icon images generated: \(sizes.count) sizes")
SWIFTEOF

# Compile and run the icon generator
echo "  Compiling icon generator..."
swiftc -o "$DIST_DIR/generate_icon" "$ICON_GENERATOR" -framework AppKit 2>&1
echo "  Running icon generator..."
"$DIST_DIR/generate_icon" "$DIST_DIR"

# Convert iconset to icns
if [ -d "$ICONSET_DIR" ] && [ "$(ls -A "$ICONSET_DIR" 2>/dev/null)" ]; then
    iconutil -c icns "$ICONSET_DIR" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
    echo "  AppIcon.icns created successfully"
    rm -rf "$ICONSET_DIR"
else
    echo "ERROR: Icon generation failed"
    exit 1
fi

# Cleanup icon generator
rm -f "$DIST_DIR/generate_icon" "$ICON_GENERATOR"

# 4. Create entitlements
echo "[4/6] Creating entitlements..."
cat > "$ENTITLEMENTS" << 'ENTEOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
</dict>
</plist>
ENTEOF
echo "  Entitlements created"

# 5. Code sign the app bundle
echo "[5/6] Code signing app bundle..."

# Sign the entire bundle with ad-hoc signature and entitlements
codesign --force --deep --sign - \
    --entitlements "$ENTITLEMENTS" \
    "$APP_BUNDLE" 2>&1

# Verify signature
echo "  Verifying signature..."
codesign --verify --deep --strict "$APP_BUNDLE" 2>&1
echo "  Code signing verified successfully"

# Cleanup entitlements
rm -f "$ENTITLEMENTS"

# 6. Create DMG
echo "[6/6] Creating DMG installer..."
rm -f "$DMG_PATH"

DMG_STAGE="$DIST_DIR/dmg_stage"
rm -rf "$DMG_STAGE"
mkdir -p "$DMG_STAGE"
cp -R "$APP_BUNDLE" "$DMG_STAGE/"
ln -s /Applications "$DMG_STAGE/Applications"

hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_STAGE" \
    -ov \
    -format UDZO \
    "$DMG_PATH" 2>&1

rm -rf "$DMG_STAGE"

echo ""
echo "=== Build Complete ==="
echo "  App:     $APP_BUNDLE"
echo "  DMG:     $DMG_PATH"
echo "  Size:    $(du -h "$DMG_PATH" | cut -f1)"
echo "  Version: $VERSION"
echo "  Signed:  ad-hoc with entitlements"
echo ""
echo "To install: Open the DMG and drag Cleankeun to Applications"
