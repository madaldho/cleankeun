#!/bin/bash
set -e

APP_NAME="Cleankeun"
BUNDLE_ID="com.cleankeun.pro"
VERSION="1.1.0"

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/.build/release"
DIST_DIR="$PROJECT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
DMG_PATH="$DIST_DIR/$APP_NAME.dmg"

echo "=== Building $APP_NAME Release ==="

# 1. Build release binary
echo "[1/4] Building release binary..."
cd "$PROJECT_DIR"
swift build -c release 2>&1
BINARY="$BUILD_DIR/$APP_NAME"

if [ ! -f "$BINARY" ]; then
    echo "ERROR: Release binary not found at $BINARY"
    exit 1
fi
echo "  Binary: $(du -h "$BINARY" | cut -f1) at $BINARY"

# 2. Create .app bundle structure
echo "[2/4] Creating app bundle..."

# Preserve existing icon if present
EXISTING_ICON=""
if [ -f "$APP_BUNDLE/Contents/Resources/AppIcon.icns" ]; then
    EXISTING_ICON="$(mktemp)"
    cp "$APP_BUNDLE/Contents/Resources/AppIcon.icns" "$EXISTING_ICON"
fi

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy binary
cp "$BINARY" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

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
    <string>1</string>
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

# 3. Generate app icon (blue brand icon using system tools)
echo "[3/4] Generating app icon..."
ICONSET_DIR="$DIST_DIR/AppIcon.iconset"
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

# Create a simple branded icon using Python (available on macOS)
python3 << 'PYEOF'
import subprocess, os, sys

dist_dir = os.environ.get("DIST_DIR", "dist")
iconset_dir = os.path.join(dist_dir, "AppIcon.iconset")

# Generate icon using sips and basic drawing via CoreGraphics (Objective-C bridge through Python)
# We'll create a simple SVG-like approach using Python's built-in capabilities
# and convert with sips

sizes = [16, 32, 64, 128, 256, 512, 1024]

for size in sizes:
    # Create a simple blue gradient icon using ImageMagick alternative
    # Since we can't guarantee ImageMagick, use a simpler approach with Python
    pass

# Use Cocoa/AppKit via PyObjC to create the icon
try:
    from AppKit import (NSImage, NSBezierPath, NSColor, NSGraphicsContext,
                        NSBitmapImageRep, NSPNGFileType, NSGradient, NSFont,
                        NSFontManager, NSString, NSMakeRect, NSMakePoint, NSMakeSize)
    from Foundation import NSData
    import math

    def create_icon(size):
        # Create bitmap
        rep = NSBitmapImageRep.alloc().initWithBitmapDataPlanes_pixelsWide_pixelsHigh_bitsPerSample_samplesPerPixel_hasAlpha_isPlanar_colorSpaceName_bytesPerRow_bitsPerPixel_(
            None, size, size, 8, 4, True, False, "NSCalibratedRGBColorSpace", 0, 0
        )
        ctx = NSGraphicsContext.graphicsContextWithBitmapImageRep_(rep)
        NSGraphicsContext.setCurrentContext_(ctx)

        s = float(size)
        corner = s * 0.22

        # Rounded rect path
        rect = NSMakeRect(0, 0, s, s)
        path = NSBezierPath.bezierPathWithRoundedRect_xRadius_yRadius_(rect, corner, corner)

        # Blue gradient background
        color1 = NSColor.colorWithCalibratedRed_green_blue_alpha_(0.10, 0.55, 1.0, 1.0)  # #1A8CFF
        color2 = NSColor.colorWithCalibratedRed_green_blue_alpha_(0.0, 0.4, 0.8, 1.0)    # #0066CC
        gradient = NSGradient.alloc().initWithStartingColor_endingColor_(color2, color1)
        gradient.drawInBezierPath_angle_(path, 90.0)

        # Draw a sparkle/broom icon symbol using bezier paths
        # Simple: draw a stylized "C" letter for Cleankeun
        cx, cy = s * 0.5, s * 0.48

        # Draw shield/broom shape - simplified sparkle icon
        NSColor.whiteColor().setFill()

        # Draw sparkle dots
        spark_size = s * 0.04
        sparkle_positions = [
            (0.3, 0.72), (0.7, 0.72), (0.5, 0.28),
            (0.25, 0.5), (0.75, 0.5),
        ]
        for px, py in sparkle_positions:
            dot = NSBezierPath.bezierPathWithOvalInRect_(
                NSMakeRect(s * px - spark_size, s * py - spark_size, spark_size * 2, spark_size * 2)
            )
            dot.fill()

        # Draw main broom/brush shape
        broom = NSBezierPath.alloc().init()
        # Handle
        handle_w = s * 0.04
        broom.moveToPoint_(NSMakePoint(cx - handle_w, s * 0.65))
        broom.lineToPoint_(NSMakePoint(cx + handle_w, s * 0.65))
        broom.lineToPoint_(NSMakePoint(cx + handle_w * 0.5, s * 0.35))
        broom.lineToPoint_(NSMakePoint(cx - handle_w * 0.5, s * 0.35))
        broom.closePath()
        broom.fill()

        # Bristles (fan shape at bottom)
        bristle = NSBezierPath.alloc().init()
        bristle.moveToPoint_(NSMakePoint(cx - s * 0.15, s * 0.22))
        bristle.lineToPoint_(NSMakePoint(cx + s * 0.15, s * 0.22))
        bristle.lineToPoint_(NSMakePoint(cx + s * 0.08, s * 0.35))
        bristle.lineToPoint_(NSMakePoint(cx - s * 0.08, s * 0.35))
        bristle.closePath()

        NSColor.colorWithCalibratedRed_green_blue_alpha_(1.0, 1.0, 1.0, 0.9).setFill()
        bristle.fill()

        ctx.flushGraphics()

        # Save as PNG
        data = rep.representationUsingType_properties_(NSPNGFileType, None)
        return data

    for size in sizes:
        data = create_icon(size)
        if data:
            name = f"icon_{size}x{size}.png"
            path = os.path.join(iconset_dir, name)
            data.writeToFile_atomically_(path, True)

            # Also create @2x versions
            if size <= 512:
                name_2x = f"icon_{size}x{size}@2x.png"
                data_2x = create_icon(size * 2)
                if data_2x:
                    path_2x = os.path.join(iconset_dir, name_2x)
                    data_2x.writeToFile_atomically_(path_2x, True)

    print("  Icon images generated successfully")

except ImportError as e:
    print(f"  Warning: PyObjC not available ({e}), skipping icon generation")
    sys.exit(0)
PYEOF

# Convert iconset to icns
if [ -d "$ICONSET_DIR" ] && [ "$(ls -A "$ICONSET_DIR" 2>/dev/null)" ]; then
    iconutil -c icns "$ICONSET_DIR" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns" 2>/dev/null || echo "  Warning: iconutil failed, app will use default icon"
    rm -rf "$ICONSET_DIR"
elif [ -n "$EXISTING_ICON" ] && [ -f "$EXISTING_ICON" ]; then
    echo "  Restoring previously built icon..."
    cp "$EXISTING_ICON" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
    rm -f "$EXISTING_ICON"
else
    echo "  Warning: No icon images generated, app will use default icon"
fi

# 4. Create DMG
echo "[4/4] Creating DMG installer..."
rm -f "$DMG_PATH"

# Create a temporary DMG directory with app and Applications symlink
DMG_STAGE="$DIST_DIR/dmg_stage"
rm -rf "$DMG_STAGE"
mkdir -p "$DMG_STAGE"
cp -R "$APP_BUNDLE" "$DMG_STAGE/"
ln -s /Applications "$DMG_STAGE/Applications"

# Create DMG
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_STAGE" \
    -ov \
    -format UDZO \
    "$DMG_PATH" 2>&1

rm -rf "$DMG_STAGE"

echo ""
echo "=== Build Complete ==="
echo "  App:  $APP_BUNDLE"
echo "  DMG:  $DMG_PATH"
echo "  Size: $(du -h "$DMG_PATH" | cut -f1)"
echo ""
echo "To install: Open the DMG and drag Cleankeun to Applications"
