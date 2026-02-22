#!/bin/bash
set -e

APP_NAME="Cleankeun"
BUNDLE_ID="com.cleankeun.pro"
VERSION="1.2.0"

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/.build/release"
DIST_DIR="$PROJECT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
DMG_PATH="$DIST_DIR/$APP_NAME.dmg"
ENTITLEMENTS="$DIST_DIR/Cleankeun.entitlements"

echo "=== Building $APP_NAME v$VERSION ==="
echo ""

# ─────────────────────────────────────────────
# Step 1: Build release binary
# ─────────────────────────────────────────────
echo "[1/7] Compiling release binary..."
swift build -c release 2>&1
BINARY="$BUILD_DIR/$APP_NAME"

if [ ! -f "$BINARY" ]; then
    echo "ERROR: Binary not found at $BINARY"
    exit 1
fi
echo "  ✓ Binary $(du -h "$BINARY" | cut -f1)"

# ─────────────────────────────────────────────
# Step 2: Assemble .app bundle
# ─────────────────────────────────────────────
echo "[2/7] Assembling app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BINARY" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod 755 "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

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
    <string>7</string>
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

echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"
echo "  ✓ App bundle assembled"

# ─────────────────────────────────────────────
# Step 3: Generate app icon (compiled Swift)
# ─────────────────────────────────────────────
echo "[3/7] Generating app icon..."
ICON_GENERATOR="$DIST_DIR/_gen_icon.swift"
ICONSET_DIR="$DIST_DIR/AppIcon.iconset"
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

cat > "$ICON_GENERATOR" << 'SWIFTEOF'
import AppKit
import Foundation

func createIcon(size: Int) -> NSBitmapImageRep {
    let s = CGFloat(size)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx
    let cg = ctx.cgContext
    let cs = CGColorSpaceCreateDeviceRGB()

    // Rounded rect clip
    let bgPath = CGPath(roundedRect: CGRect(x: 0, y: 0, width: s, height: s),
                        cornerWidth: s * 0.22, cornerHeight: s * 0.22, transform: nil)
    cg.addPath(bgPath); cg.clip()

    // Blue gradient
    let gc = [CGColor(colorSpace: cs, components: [0.0, 0.30, 0.80, 1.0])!,
              CGColor(colorSpace: cs, components: [0.10, 0.55, 1.0, 1.0])!,
              CGColor(colorSpace: cs, components: [0.30, 0.66, 1.0, 1.0])!] as CFArray
    let grad = CGGradient(colorsSpace: cs, colors: gc, locations: [0.0, 0.5, 1.0])!
    cg.drawLinearGradient(grad, start: CGPoint(x: s/2, y: 0), end: CGPoint(x: s/2, y: s), options: [])

    // Top highlight
    let oc = [CGColor(colorSpace: cs, components: [1,1,1,0.12])!,
              CGColor(colorSpace: cs, components: [1,1,1,0])!] as CFArray
    let og = CGGradient(colorsSpace: cs, colors: oc, locations: [0,1])!
    cg.drawLinearGradient(og, start: CGPoint(x: s/2, y: s), end: CGPoint(x: s/2, y: s/2), options: [])

    // Sweep arc
    let cx = s * 0.5, cy = s * 0.5
    let sa = CGFloat.pi/2 - (0.2*2 * .pi) + .pi/4
    let ea = CGFloat.pi/2 - (0.9*2 * .pi) + .pi/4
    cg.saveGState()
    cg.setStrokeColor(CGColor(colorSpace: cs, components: [1,1,1,0.9])!)
    cg.setLineWidth(s * 0.065); cg.setLineCap(.round)
    cg.addArc(center: CGPoint(x: cx, y: cy), radius: s*0.28, startAngle: sa, endAngle: ea, clockwise: true)
    cg.strokePath()
    cg.setStrokeColor(CGColor(colorSpace: cs, components: [1,1,1,0.3])!)
    cg.setLineWidth(s * 0.065 * 1.5)
    cg.addArc(center: CGPoint(x: cx, y: cy), radius: s*0.28,
              startAngle: sa - (sa - ea)*0.6, endAngle: ea, clockwise: true)
    cg.strokePath()
    cg.restoreGState()

    // Sparkles
    func sparkle(_ x: CGFloat, _ y: CGFloat, _ sz: CGFloat, _ a: CGFloat = 0.95) {
        let r = sz/2, inn = r*0.3
        cg.saveGState()
        cg.setFillColor(CGColor(colorSpace: cs, components: [1,1,1,a])!)
        let p = CGMutablePath()
        p.move(to: CGPoint(x: x, y: y+r))
        p.addQuadCurve(to: CGPoint(x: x+r, y: y), control: CGPoint(x: x+inn*0.4, y: y+inn*0.4))
        p.addQuadCurve(to: CGPoint(x: x, y: y-r), control: CGPoint(x: x+inn*0.4, y: y-inn*0.4))
        p.addQuadCurve(to: CGPoint(x: x-r, y: y), control: CGPoint(x: x-inn*0.4, y: y-inn*0.4))
        p.addQuadCurve(to: CGPoint(x: x, y: y+r), control: CGPoint(x: x-inn*0.4, y: y+inn*0.4))
        p.closeSubpath()
        cg.addPath(p); cg.fillPath()
        cg.setShadow(offset: .zero, blur: sz*0.4,
                     color: CGColor(colorSpace: cs, components: [1,1,1,a*0.5])!)
        cg.addPath(p); cg.fillPath()
        cg.restoreGState()
    }
    sparkle(cx - s*0.12, cy + s*0.12, s*0.20)
    sparkle(cx + s*0.18, cy - s*0.08, s*0.10)
    sparkle(cx + s*0.05, cy + s*0.25, s*0.06, 0.6)

    ctx.flushGraphics(); NSGraphicsContext.current = nil
    return rep
}

let dir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "dist"
let out = "\(dir)/AppIcon.iconset"
for (name, px) in [("icon_16x16",16),("icon_16x16@2x",32),("icon_32x32",32),("icon_32x32@2x",64),
                    ("icon_128x128",128),("icon_128x128@2x",256),("icon_256x256",256),
                    ("icon_256x256@2x",512),("icon_512x512",512),("icon_512x512@2x",1024)] {
    let d = createIcon(size: px).representation(using: .png, properties: [:])!
    try! d.write(to: URL(fileURLWithPath: "\(out)/\(name).png"))
}
print("  ✓ 10 icon sizes generated")
SWIFTEOF

swiftc -o "$DIST_DIR/_gen_icon" "$ICON_GENERATOR" -framework AppKit 2>&1
"$DIST_DIR/_gen_icon" "$DIST_DIR"
iconutil -c icns "$ICONSET_DIR" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
echo "  ✓ AppIcon.icns created"
rm -rf "$ICONSET_DIR" "$DIST_DIR/_gen_icon" "$ICON_GENERATOR"

# ─────────────────────────────────────────────
# Step 4: Generate DMG background image
# ─────────────────────────────────────────────
echo "[4/7] Generating DMG background..."
BG_GENERATOR="$DIST_DIR/_gen_bg.swift"
BG_IMAGE="$DIST_DIR/_dmg_bg.png"

cat > "$BG_GENERATOR" << 'SWIFTEOF'
import AppKit
import Foundation

// DMG installer background — 660x400 @2x retina
// Vibrant blue gradient with visible arrow and branded text
let w = 660, h = 400
let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: w * 2, pixelsHigh: h * 2,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: w, height: h)

let ctx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.current = ctx
let cg = ctx.cgContext
let cs = CGColorSpaceCreateDeviceRGB()
let W = CGFloat(w), H = CGFloat(h)

cg.scaleBy(x: 2, y: 2)

// ── Background: rich blue-to-dark gradient ──
let bgc = [CGColor(colorSpace: cs, components: [0.04, 0.12, 0.28, 1])!,
           CGColor(colorSpace: cs, components: [0.02, 0.06, 0.16, 1])!,
           CGColor(colorSpace: cs, components: [0.01, 0.03, 0.10, 1])!] as CFArray
let bgg = CGGradient(colorsSpace: cs, colors: bgc, locations: [0, 0.5, 1])!
cg.drawLinearGradient(bgg, start: CGPoint(x: W/2, y: H), end: CGPoint(x: W/2, y: 0), options: [])

// ── Large soft blue glow top-center ──
cg.saveGState()
let g1c = [CGColor(colorSpace: cs, components: [0.15, 0.45, 0.95, 0.20])!,
           CGColor(colorSpace: cs, components: [0.10, 0.35, 0.85, 0.0])!] as CFArray
let g1g = CGGradient(colorsSpace: cs, colors: g1c, locations: [0, 1])!
cg.drawRadialGradient(g1g, startCenter: CGPoint(x: W*0.5, y: H*0.75),
    startRadius: 0, endCenter: CGPoint(x: W*0.5, y: H*0.75), endRadius: W*0.55, options: [])
cg.restoreGState()

// ── Secondary glow bottom-left ──
cg.saveGState()
let g2c = [CGColor(colorSpace: cs, components: [0.05, 0.25, 0.70, 0.12])!,
           CGColor(colorSpace: cs, components: [0.05, 0.20, 0.60, 0.0])!] as CFArray
let g2g = CGGradient(colorsSpace: cs, colors: g2c, locations: [0, 1])!
cg.drawRadialGradient(g2g, startCenter: CGPoint(x: W*0.2, y: H*0.2),
    startRadius: 0, endCenter: CGPoint(x: W*0.2, y: H*0.2), endRadius: W*0.35, options: [])
cg.restoreGState()

// ── Decorative subtle grid dots ──
cg.saveGState()
cg.setFillColor(CGColor(colorSpace: cs, components: [1, 1, 1, 0.03])!)
let dotSpacing: CGFloat = 30
var dy: CGFloat = 10
while dy < H {
    var dx: CGFloat = 10
    while dx < W {
        cg.fillEllipse(in: CGRect(x: dx - 0.75, y: dy - 0.75, width: 1.5, height: 1.5))
        dx += dotSpacing
    }
    dy += dotSpacing
}
cg.restoreGState()

// ── Horizontal divider line where icons sit ──
cg.saveGState()
let lineY = H * 0.34
cg.setStrokeColor(CGColor(colorSpace: cs, components: [1, 1, 1, 0.06])!)
cg.setLineWidth(0.5)
cg.move(to: CGPoint(x: W * 0.1, y: lineY))
cg.addLine(to: CGPoint(x: W * 0.9, y: lineY))
cg.strokePath()
cg.restoreGState()

// ── Arrow: prominent, centered between icon positions ──
let arrowY = H * 0.50
let arrowX = W * 0.50
let arrowLen: CGFloat = 56
let arrowHead: CGFloat = 16

cg.saveGState()
// Arrow glow
cg.setShadow(offset: .zero, blur: 8,
    color: CGColor(colorSpace: cs, components: [0.3, 0.6, 1.0, 0.4])!)
cg.setStrokeColor(CGColor(colorSpace: cs, components: [0.5, 0.75, 1.0, 0.7])!)
cg.setLineWidth(3.0)
cg.setLineCap(.round)
cg.setLineJoin(.round)

// Shaft
cg.move(to: CGPoint(x: arrowX - arrowLen/2, y: arrowY))
cg.addLine(to: CGPoint(x: arrowX + arrowLen/2, y: arrowY))
cg.strokePath()

// Head
cg.move(to: CGPoint(x: arrowX + arrowLen/2 - arrowHead, y: arrowY + arrowHead*0.55))
cg.addLine(to: CGPoint(x: arrowX + arrowLen/2, y: arrowY))
cg.addLine(to: CGPoint(x: arrowX + arrowLen/2 - arrowHead, y: arrowY - arrowHead*0.55))
cg.strokePath()
cg.restoreGState()

// ── "Drag to Applications" text ──
let instrAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 12, weight: .medium),
    .foregroundColor: NSColor(calibratedRed: 0.6, green: 0.78, blue: 1.0, alpha: 0.65)
]
let instrText = NSAttributedString(string: "Drag to Applications to install", attributes: instrAttrs)
let instrSize = instrText.size()
instrText.draw(at: NSPoint(x: (W - instrSize.width) / 2, y: H * 0.30))

// ── App name at top ──
let titleAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 20, weight: .bold),
    .foregroundColor: NSColor(calibratedWhite: 1.0, alpha: 0.85)
]
let titleText = NSAttributedString(string: "Cleankeun Pro", attributes: titleAttrs)
let titleSize = titleText.size()
titleText.draw(at: NSPoint(x: (W - titleSize.width) / 2, y: H * 0.82))

// ── Subtitle ──
let subAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 11, weight: .regular),
    .foregroundColor: NSColor(calibratedRed: 0.55, green: 0.72, blue: 0.95, alpha: 0.55)
]
let subText = NSAttributedString(string: "System Cleaner & Optimizer", attributes: subAttrs)
let subSize = subText.size()
subText.draw(at: NSPoint(x: (W - subSize.width) / 2, y: H * 0.76))

// ── Version badge bottom-right ──
let verAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.monospacedSystemFont(ofSize: 9, weight: .medium),
    .foregroundColor: NSColor(calibratedWhite: 1.0, alpha: 0.25)
]
let verText = NSAttributedString(string: "v1.2.0", attributes: verAttrs)
verText.draw(at: NSPoint(x: W - 50, y: 10))

ctx.flushGraphics()
NSGraphicsContext.current = nil

let data = rep.representation(using: .png, properties: [:])!
let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "dist/_dmg_bg.png"
try! data.write(to: URL(fileURLWithPath: outPath))
print("  ✓ DMG background generated (\(w)x\(h) @2x)")
SWIFTEOF

swiftc -o "$DIST_DIR/_gen_bg" "$BG_GENERATOR" -framework AppKit 2>&1
"$DIST_DIR/_gen_bg" "$BG_IMAGE"
rm -f "$DIST_DIR/_gen_bg" "$BG_GENERATOR"

# ─────────────────────────────────────────────
# Step 5: Code sign
# ─────────────────────────────────────────────
echo "[5/7] Code signing..."

# Clean extended attributes before signing
xattr -cr "$APP_BUNDLE"

cat > "$ENTITLEMENTS" << 'ENTEOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
</dict>
</plist>
ENTEOF

codesign --force --deep --sign - \
    --entitlements "$ENTITLEMENTS" \
    "$APP_BUNDLE" 2>&1

codesign --verify --deep --strict "$APP_BUNDLE" 2>&1
echo "  ✓ Signed and verified"
rm -f "$ENTITLEMENTS"

# ─────────────────────────────────────────────
# Step 6: Create professional DMG with create-dmg
# ─────────────────────────────────────────────
echo "[6/7] Creating DMG installer..."
rm -f "$DMG_PATH"

# Use create-dmg for professional DMG layout
# Window size 660x400, app on left, Applications on right
create-dmg \
    --volname "$APP_NAME" \
    --volicon "$APP_BUNDLE/Contents/Resources/AppIcon.icns" \
    --background "$BG_IMAGE" \
    --window-pos 200 120 \
    --window-size 660 400 \
    --icon-size 120 \
    --icon "$APP_NAME.app" 160 190 \
    --app-drop-link 500 190 \
    --text-size 14 \
    --hide-extension "$APP_NAME.app" \
    --no-internet-enable \
    "$DMG_PATH" \
    "$APP_BUNDLE" \
    2>&1 || {
        # Fallback: if create-dmg not available, use hdiutil
        echo "  create-dmg failed, falling back to hdiutil..."
        DMG_STAGE="$DIST_DIR/dmg_stage"
        rm -rf "$DMG_STAGE"
        mkdir -p "$DMG_STAGE"
        cp -R "$APP_BUNDLE" "$DMG_STAGE/"
        ln -s /Applications "$DMG_STAGE/Applications"
        xattr -cr "$DMG_STAGE/$APP_NAME.app"
        hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_STAGE" \
            -ov -format UDZO "$DMG_PATH" 2>&1
        rm -rf "$DMG_STAGE"
    }

rm -f "$BG_IMAGE"
echo "  ✓ DMG created: $(du -h "$DMG_PATH" | cut -f1)"

# ─────────────────────────────────────────────
# Step 7: Verify DMG
# ─────────────────────────────────────────────
echo "[7/7] Verifying DMG..."
VERIFY_MOUNT="/tmp/cleankeun_verify_$$"
hdiutil attach "$DMG_PATH" -mountpoint "$VERIFY_MOUNT" -nobrowse -quiet 2>&1

if [ -d "$VERIFY_MOUNT/$APP_NAME.app/Contents/MacOS" ] && \
   [ -f "$VERIFY_MOUNT/$APP_NAME.app/Contents/MacOS/$APP_NAME" ]; then
    echo "  ✓ App bundle intact"
    echo "  ✓ Binary: $(file "$VERIFY_MOUNT/$APP_NAME.app/Contents/MacOS/$APP_NAME" | sed 's/.*: //')"
    echo "  ✓ Icon:   $(du -h "$VERIFY_MOUNT/$APP_NAME.app/Contents/Resources/AppIcon.icns" | cut -f1)"

    if [ -L "$VERIFY_MOUNT/Applications" ]; then
        echo "  ✓ Applications symlink present"
    else
        echo "  ⚠ No Applications symlink (create-dmg uses app-drop-link instead)"
    fi

    codesign --verify --deep --strict "$VERIFY_MOUNT/$APP_NAME.app" 2>&1 \
        && echo "  ✓ Signature valid" \
        || echo "  ✗ Signature invalid!"

    CT=$(mdls -name kMDItemContentType -raw "$VERIFY_MOUNT/$APP_NAME.app" 2>/dev/null)
    echo "  ✓ Content type: $CT"
else
    echo "  ✗ ERROR: DMG structure is broken!"
    ls -la "$VERIFY_MOUNT/" 2>&1
fi

hdiutil detach "$VERIFY_MOUNT" -quiet 2>&1

echo ""
echo "════════════════════════════════════════════"
echo "  BUILD COMPLETE"
echo "════════════════════════════════════════════"
echo "  App:     $APP_BUNDLE"
echo "  DMG:     $DMG_PATH"
echo "  Size:    $(du -h "$DMG_PATH" | cut -f1)"
echo "  Version: $VERSION"
echo ""
echo "  Install:"
echo "    1. Open Cleankeun.dmg"
echo "    2. Drag Cleankeun → Applications"
echo "    3. First launch: Right-click → Open → Open"
echo "════════════════════════════════════════════"
