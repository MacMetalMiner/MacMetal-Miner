#!/bin/bash
# ╔═══════════════════════════════════════════════════════════════╗
# ║       Mac Metal Miner - Build Script                                ║
# ║          GPU Miner v10.0.0                                     ║
# ╚═══════════════════════════════════════════════════════════════╝

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║       Mac Metal Miner - Build Script                               ║"
echo "║          GPU Miner v10.0.0                                    ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

# Remove quarantine
echo "Removing quarantine flags..."
xattr -cr . 2>/dev/null

# Check for Swift
if ! command -v swiftc &> /dev/null; then
    echo "❌ Swift compiler not found!"
    echo "   Install: xcode-select --install"
    exit 1
fi

echo "✓ Swift compiler found"

APP_NAME="Mac Metal Miner"
APP_BUNDLE="$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

# Remove old app
rm -rf "$APP_BUNDLE"

echo "Creating app bundle..."
mkdir -p "$MACOS"
mkdir -p "$RESOURCES"

# Generate App Icon — DLT WWW Squircle
echo "Generating squircle app icon..."
ICONSET="$RESOURCES/AppIcon.iconset"
mkdir -p "$ICONSET"

cat > /tmp/create_icon.swift << 'SWIFTICON'
import AppKit

let iconsetPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"

func appleSquirclePath(cx: CGFloat, cy: CGFloat, halfW: CGFloat, halfH: CGFloat) -> NSBezierPath {
    let path = NSBezierPath()
    let n: CGFloat = 5.0
    let points = 360
    for i in 0...points {
        let t = CGFloat(i) / CGFloat(points) * 2 * .pi
        let cosT = cos(t), sinT = sin(t)
        let x = cx + halfW * pow(abs(cosT), 2/n) * (cosT >= 0 ? 1 : -1)
        let y = cy + halfH * pow(abs(sinT), 2/n) * (sinT >= 0 ? 1 : -1)
        if i == 0 { path.move(to: NSPoint(x: x, y: y)) }
        else { path.line(to: NSPoint(x: x, y: y)) }
    }
    path.close()
    return path
}

func createIcon(size: Int) -> NSImage {
    let s = CGFloat(size)
    let image = NSImage(size: NSSize(width: s, height: s))
    image.lockFocus()
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.clear(CGRect(x: 0, y: 0, width: s, height: s))

    // Apple icon grid: squircle ~82% of canvas, centered with padding for drop shadow
    let cx = s / 2
    let cy = s / 2
    let iconRadius = s * 0.41

    // Black fill
    let fill = appleSquirclePath(cx: cx, cy: cy, halfW: iconRadius, halfH: iconRadius)
    NSColor.black.setFill()
    fill.fill()

    // Green border (inset from fill)
    let borderInset = s * 0.035
    let border = appleSquirclePath(cx: cx, cy: cy, halfW: iconRadius - borderInset, halfH: iconRadius - borderInset)
    NSColor(red: 0, green: 1, blue: 0, alpha: 1).setStroke()
    border.lineWidth = s * 0.025
    border.stroke()

    // WWW text
    let fontSize = s * 0.18
    let font = NSFont(name: "Arial-BoldMT", size: fontSize) ?? NSFont.boldSystemFont(ofSize: fontSize)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor(red: 0, green: 1, blue: 0, alpha: 1),
        .kern: s * 0.02
    ]
    let text = "WWW"
    let textSize = text.size(withAttributes: attrs)
    text.draw(at: NSPoint(x: (s - textSize.width) / 2, y: (s - textSize.height) / 2), withAttributes: attrs)

    image.unlockFocus()
    return image
}

let sizes = [16, 32, 64, 128, 256, 512, 1024]
try? FileManager.default.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)
for size in sizes {
    let img = createIcon(size: size)
    if let tiff = img.tiffRepresentation,
       let bitmap = NSBitmapImageRep(data: tiff),
       let png = bitmap.representation(using: .png, properties: [:]) {
        try? png.write(to: URL(fileURLWithPath: "\(iconsetPath)/icon_\(size)x\(size).png"))
    }
}
print("Apple squircle WWW icons generated")
SWIFTICON

swiftc -o /tmp/create_icon /tmp/create_icon.swift -framework AppKit 2>/dev/null
if [ -f /tmp/create_icon ]; then
    /tmp/create_icon "$ICONSET"
    rm -f /tmp/create_icon /tmp/create_icon.swift
else
    echo "Swift icon compilation failed"
fi

# Create iconset with proper naming for iconutil
if [ -f "$ICONSET/icon_512x512.png" ]; then
    cd "$ICONSET"
    cp icon_16x16.png icon_16x16.png 2>/dev/null
    cp icon_32x32.png icon_16x16@2x.png 2>/dev/null
    cp icon_32x32.png icon_32x32.png 2>/dev/null
    cp icon_64x64.png icon_32x32@2x.png 2>/dev/null
    cp icon_128x128.png icon_128x128.png 2>/dev/null
    cp icon_256x256.png icon_128x128@2x.png 2>/dev/null
    cp icon_256x256.png icon_256x256.png 2>/dev/null
    cp icon_512x512.png icon_256x256@2x.png 2>/dev/null
    cp icon_512x512.png icon_512x512.png 2>/dev/null
    cp icon_1024x1024.png icon_512x512@2x.png 2>/dev/null
    cd "$DIR"
    
    # Create icns
    iconutil -c icns "$ICONSET" -o "$RESOURCES/AppIcon.icns" 2>/dev/null
    if [ -f "$RESOURCES/AppIcon.icns" ]; then
        echo "✓ Squircle app icon with NEX badge created"
    else
        echo "⚠ Could not create .icns, using fallback"
    fi
fi

# Copy Metal shader
if [ -f "SHA256.metal" ]; then
    cp SHA256.metal "$RESOURCES/"
    echo "✓ Metal shader copied to $RESOURCES/"
    # Verify it's there
    if [ -f "$RESOURCES/SHA256.metal" ]; then
        echo "  Verified: $RESOURCES/SHA256.metal exists"
    else
        echo "  WARNING: Copy failed!"
    fi
else
    echo "⚠ SHA256.metal not found in current directory"
    echo "  Current directory: $(pwd)"
    echo "  Contents: $(ls -la)"
fi

# Compile the app
echo "Compiling Mac Metal Miner (this may take a moment)..."
swiftc -O -parse-as-library \
    -o "$MACOS/$APP_NAME" \
    MacMetalMinerProMax.swift \
    -framework Metal \
    -framework Foundation \
    -framework SwiftUI \
    -framework AppKit \
    -framework AVFoundation \
    -framework UserNotifications \
    -framework IOKit \
    -framework Security \
    -framework Network \
    -target arm64-apple-macos14.0 \
    2>&1

if [ $? -eq 0 ] && [ -f "$MACOS/$APP_NAME" ]; then
    echo "✓ Compilation successful"
    
    # Create Info.plist
    cat > "$CONTENTS/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Mac Metal Miner</string>
    <key>CFBundleIdentifier</key>
    <string>com.mmm.macmetalminer</string>
    <key>CFBundleName</key>
    <string>Mac Metal Miner</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>10.0.0</string>
    <key>CFBundleVersion</key>
    <string>1000</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <false/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>
</dict>
</plist>
PLIST

    echo ""
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                    ✅ BUILD SUCCESSFUL!                       ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "App created: $APP_BUNDLE"
    echo ""
    echo "Mac Metal Miner Features:"
    echo "  • GPU-accelerated SHA256d mining via Metal"
    echo "  • Use nex-wallet CLI for wallet operations"
    echo "  • NEX address validation (nx1, nxrt1, tnx1, N)"
    echo "  • Real-time hashrate monitoring"
    echo "  • GPU monitoring gauges"
    echo "  • Session log file ~/Library/Logs/MacMetalMiner/session.log"
    echo ""
    
    # Add to Dock automatically
    APP_PATH="$DIR/$APP_BUNDLE"
    echo "Adding to Dock..."
    defaults write com.apple.dock persistent-apps -array-add "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>$APP_PATH</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>"
    killall Dock
    echo "✓ Added to Dock"
    
    read -p "Open the app now? (y/n): " OPEN_APP
    if [ "$OPEN_APP" = "y" ] || [ "$OPEN_APP" = "Y" ]; then
        open "$APP_BUNDLE"
        echo ""
        echo "Look for the Ⓝ icon in your menu bar!"
    fi
else
    echo ""
    echo "❌ Build failed!"
    echo ""
    echo "Try these troubleshooting steps:"
    echo "1. xattr -cr ."
    echo "2. Make sure Xcode command line tools are installed:"
    echo "   xcode-select --install"
fi
