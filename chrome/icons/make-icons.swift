// Draws the extension's icons: a white Ethereum diamond on an indigo rounded
// square, at every size the manifest lists.
//
// Run from this directory: swift make-icons.swift

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let sizes = [16, 32, 48, 128]

func drawIcon(size: Int) -> CGImage {
    let s = CGFloat(size)
    let ctx = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!

    // Background: rounded square with a top-to-bottom indigo gradient.
    let inset = s * 0.04
    let rect = CGRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let radius = rect.width * 0.22
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
    ctx.clip()
    let gradient = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
        colors: [
            CGColor(srgbRed: 0.39, green: 0.40, blue: 0.95, alpha: 1),  // #6366F1
            CGColor(srgbRed: 0.26, green: 0.22, blue: 0.79, alpha: 1),  // #4338CA
        ] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: s), end: .zero, options: [])
    ctx.resetClip()

    // Diamond, in a unit box mapped onto the middle of the icon (y points up).
    let height = s * 0.64
    let width = height * 0.62
    let origin = CGPoint(x: (s - width) / 2, y: (s - height) / 2)
    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: origin.x + x * width, y: origin.y + y * height)
    }
    func fill(_ points: [CGPoint], alpha: CGFloat) {
        ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: alpha))
        ctx.addLines(between: points)
        ctx.closePath()
        ctx.fillPath()
    }
    // Upper half: left and right faces, shaded apart.
    fill([p(0.5, 1), p(0, 0.49), p(0.5, 0.36)], alpha: 1)
    fill([p(0.5, 1), p(1, 0.49), p(0.5, 0.36)], alpha: 0.82)
    // Lower chevron, split the same way.
    fill([p(0, 0.42), p(0.5, 0.29), p(0.5, 0)], alpha: 0.9)
    fill([p(1, 0.42), p(0.5, 0.29), p(0.5, 0)], alpha: 0.72)

    return ctx.makeImage()!
}

for size in sizes {
    let url = URL(fileURLWithPath: "icon\(size).png")
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, drawIcon(size: size), nil)
    guard CGImageDestinationFinalize(dest) else { fatalError("failed to write \(url.path)") }
    print("wrote \(url.lastPathComponent)")
}
