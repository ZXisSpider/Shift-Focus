import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let assets = root.appendingPathComponent("Assets")
let iconset = assets.appendingPathComponent("AppIcon.iconset")
let iconFile = assets.appendingPathComponent("AppIcon.icns")

try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let icons: [(name: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    let r = CGFloat((hex >> 16) & 0xff) / 255
    let g = CGFloat((hex >> 8) & 0xff) / 255
    let b = CGFloat(hex & 0xff) / 255
    return CGColor(red: r, green: g, blue: b, alpha: alpha)
}

func roundedRect(_ rect: CGRect, radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func drawIcon(size: Int) -> CGImage {
    let width = size
    let height = size
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!

    let s = CGFloat(size)
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    context.clear(CGRect(x: 0, y: 0, width: s, height: s))

    let outer = CGRect(x: s * 0.055, y: s * 0.055, width: s * 0.89, height: s * 0.89)
    context.saveGState()
    context.addPath(roundedRect(outer, radius: s * 0.205))
    context.clip()

    let gradient = CGGradient(
        colorsSpace: colorSpace,
        colors: [color(0xffffff), color(0xf7f7f5), color(0xffffff)] as CFArray,
        locations: [0, 0.58, 1]
    )!
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: outer.minX, y: outer.maxY),
        end: CGPoint(x: outer.maxX, y: outer.minY),
        options: []
    )

    let glow = CGGradient(
        colorsSpace: colorSpace,
        colors: [color(0x000000, alpha: 0.035), color(0x000000, alpha: 0)] as CFArray,
        locations: [0, 1]
    )!
    context.drawRadialGradient(
        glow,
        startCenter: CGPoint(x: s * 0.50, y: s * 0.52),
        startRadius: 0,
        endCenter: CGPoint(x: s * 0.50, y: s * 0.52),
        endRadius: s * 0.44,
        options: [.drawsAfterEndLocation]
    )

    context.restoreGState()

    context.setStrokeColor(color(0x000000, alpha: 0.035))
    context.setLineWidth(max(1, s * 0.006))
    context.addPath(roundedRect(outer.insetBy(dx: s * 0.008, dy: s * 0.008), radius: s * 0.19))
    context.strokePath()

    func bladePath(_ points: [CGPoint], controls: [(CGPoint, CGPoint, CGPoint)]) -> CGPath {
        let path = CGMutablePath()
        path.move(to: points[0])
        for curve in controls {
            path.addCurve(to: curve.2, control1: curve.0, control2: curve.1)
        }
        path.closeSubpath()
        return path
    }

    let upperBlade = bladePath(
        [CGPoint(x: s * 0.285, y: s * 0.625)],
        controls: [
            (
                CGPoint(x: s * 0.430, y: s * 0.760),
                CGPoint(x: s * 0.670, y: s * 0.790),
                CGPoint(x: s * 0.805, y: s * 0.610)
            ),
            (
                CGPoint(x: s * 0.900, y: s * 0.470),
                CGPoint(x: s * 0.885, y: s * 0.305),
                CGPoint(x: s * 0.785, y: s * 0.292)
            ),
            (
                CGPoint(x: s * 0.708, y: s * 0.282),
                CGPoint(x: s * 0.706, y: s * 0.355),
                CGPoint(x: s * 0.706, y: s * 0.405)
            ),
            (
                CGPoint(x: s * 0.704, y: s * 0.555),
                CGPoint(x: s * 0.525, y: s * 0.650),
                CGPoint(x: s * 0.310, y: s * 0.604)
            ),
            (
                CGPoint(x: s * 0.250, y: s * 0.592),
                CGPoint(x: s * 0.247, y: s * 0.650),
                CGPoint(x: s * 0.285, y: s * 0.625)
            )
        ]
    )

    let lowerBlade = bladePath(
        [CGPoint(x: s * 0.332, y: s * 0.270)],
        controls: [
            (
                CGPoint(x: s * 0.455, y: s * 0.435),
                CGPoint(x: s * 0.505, y: s * 0.520),
                CGPoint(x: s * 0.585, y: s * 0.535)
            ),
            (
                CGPoint(x: s * 0.675, y: s * 0.552),
                CGPoint(x: s * 0.752, y: s * 0.455),
                CGPoint(x: s * 0.704, y: s * 0.365)
            ),
            (
                CGPoint(x: s * 0.650, y: s * 0.265),
                CGPoint(x: s * 0.520, y: s * 0.212),
                CGPoint(x: s * 0.340, y: s * 0.215)
            ),
            (
                CGPoint(x: s * 0.258, y: s * 0.217),
                CGPoint(x: s * 0.276, y: s * 0.345),
                CGPoint(x: s * 0.332, y: s * 0.270)
            )
        ]
    )

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -s * 0.022), blur: s * 0.025, color: color(0x000000, alpha: 0.22))
    context.addPath(upperBlade)
    context.setFillColor(color(0x111111))
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -s * 0.018), blur: s * 0.032, color: color(0x000000, alpha: 0.20))
    context.addPath(lowerBlade)
    context.setFillColor(color(0x030303))
    context.fillPath()
    context.restoreGState()

    return context.makeImage()!
}

func writePNG(_ image: CGImage, to url: URL) {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fatalError("Could not create image destination for \(url.path)")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        fatalError("Could not write \(url.path)")
    }
}

for icon in icons {
    writePNG(drawIcon(size: icon.pixels), to: iconset.appendingPathComponent(icon.name))
}

if FileManager.default.fileExists(atPath: iconFile.path) {
    try FileManager.default.removeItem(at: iconFile)
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", iconFile.path]
try process.run()
process.waitUntilExit()

guard process.terminationStatus == 0 else {
    fatalError("iconutil failed with status \(process.terminationStatus)")
}

print("Generated \(iconFile.path)")
