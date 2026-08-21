import CoreGraphics
import Foundation
import ImageIO

let canvas = CGFloat(1024)
let outputPath = CommandLine.arguments.count > 2
    ? CommandLine.arguments[2]
    : "dist/AppIcon.iconset/icon_512x512@2x.png"

func color(_ white: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: white, green: white, blue: white, alpha: alpha)
}

func makeContext(_ side: Int) -> CGContext {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    return CGContext(
        data: nil,
        width: side,
        height: side,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
}

func renderIcon(scale: CGFloat) -> CGImage {
    let ctx = makeContext(Int(canvas * scale))
    ctx.scaleBy(x: scale, y: scale)

    let fullRect = CGRect(x: 0, y: 0, width: canvas, height: canvas)
    let cornerRadius = canvas * 0.2225
    let squircle = CGPath(
        roundedRect: fullRect,
        cornerWidth: cornerRadius,
        cornerHeight: cornerRadius,
        transform: nil
    )

    ctx.addPath(squircle)
    ctx.clip()

    let bgColors = [color(0.02), color(0.11)] as CFArray
    let bgGradient = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
        colors: bgColors,
        locations: [0, 1]
    )!
    ctx.drawLinearGradient(
        bgGradient,
        start: CGPoint(x: 0, y: canvas),
        end: CGPoint(x: canvas, y: 0),
        options: []
    )

    let islandRect = CGRect(
        x: (canvas - 520) / 2,
        y: (canvas - 150) / 2,
        width: 520,
        height: 150
    )
    let islandPath = CGPath(
        roundedRect: islandRect,
        cornerWidth: 75,
        cornerHeight: 75,
        transform: nil
    )

    ctx.saveGState()
    ctx.setShadow(
        offset: CGSize(width: 0, height: -12),
        blur: 42,
        color: CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.10)
    )
    ctx.addPath(islandPath)
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(islandPath)
    ctx.clip()

    let islandColors = [color(0.99), color(0.72)] as CFArray
    let islandGradient = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
        colors: islandColors,
        locations: [0, 1]
    )!
    ctx.drawLinearGradient(
        islandGradient,
        start: CGPoint(x: 0, y: islandRect.maxY),
        end: CGPoint(x: 0, y: islandRect.minY),
        options: []
    )

    let barWidth: CGFloat = 26
    let barRadius: CGFloat = 13
    let barHeights: [CGFloat] = [46, 92, 62]
    var barX = islandRect.minX + 104
    for barHeight in barHeights {
        let barY = islandRect.midY - barHeight / 2
        let bar = CGPath(
            roundedRect: CGRect(x: barX, y: barY, width: barWidth, height: barHeight),
            cornerWidth: barRadius,
            cornerHeight: barRadius,
            transform: nil
        )
        ctx.addPath(bar)
        ctx.setFillColor(color(0.05))
        ctx.fillPath()
        barX += barWidth + 30
    }

    let dotDiameter: CGFloat = 58
    let dotCenter = CGPoint(
        x: islandRect.maxX - 96,
        y: islandRect.midY
    )
    let dot = CGRect(
        x: dotCenter.x - dotDiameter / 2,
        y: dotCenter.y - dotDiameter / 2,
        width: dotDiameter,
        height: dotDiameter
    )
    ctx.setFillColor(color(0.05))
    ctx.fillEllipse(in: dot)

    ctx.restoreGState()

    ctx.addPath(CGPath(
        roundedRect: fullRect.insetBy(dx: 5, dy: 5),
        cornerWidth: cornerRadius - 5,
        cornerHeight: cornerRadius - 5,
        transform: nil
    ))
    ctx.setStrokeColor(color(1, 0.07))
    ctx.setLineWidth(2.5)
    ctx.strokePath()

    return ctx.makeImage()!
}

func writePNG(_ image: CGImage, to path: String) {
    let url = URL(fileURLWithPath: path) as CFURL
    guard let destination = CGImageDestinationCreateWithURL(url, "public.png" as CFString, 1, nil) else {
        fatalError("No se pudo crear \(path)")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        fatalError("No se pudo escribir \(path)")
    }
}

let master = renderIcon(scale: 1)
let entries: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

let directory = (outputPath as NSString).deletingLastPathComponent
try? FileManager.default.createDirectory(
    atPath: directory,
    withIntermediateDirectories: true
)

for (name, side) in entries {
    let scaled = makeContext(side)
    scaled.interpolationQuality = .high
    let rect = CGRect(x: 0, y: 0, width: side, height: side)
    scaled.draw(master, in: rect)
    writePNG(scaled.makeImage()!, to: "\(directory)/\(name)")
    print("✔ \(name)")
}
