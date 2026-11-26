// Renders a 1024×1024 app icon: a white map pin holding an open book on a blue gradient.
// Usage: swift make_icon.swift <output.png>
import AppKit
import CoreGraphics
import Foundation

let size = 1024.0
let out = CommandLine.arguments.dropFirst().first ?? "AppIcon.png"
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
                    space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!

func rgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor {
    CGColor(colorSpace: space, components: [r, g, b, a])!
}

// Coordinates are y-up.
// Background: app blue (Theme.blue = 0.02, 0.43, 1.0) as a diagonal gradient.
let bg = CGGradient(colorsSpace: space,
                    colors: [rgb(0.25, 0.62, 1.0), rgb(0.02, 0.43, 1.0), rgb(0.0, 0.27, 0.72)] as CFArray,
                    locations: [0, 0.5, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: size), end: CGPoint(x: size, y: 0), options: [])

// Soft glow behind the pin head.
let glow = CGGradient(colorsSpace: space, colors: [rgb(1, 1, 1, 0.22), rgb(1, 1, 1, 0)] as CFArray, locations: [0, 1])!
ctx.drawRadialGradient(glow, startCenter: CGPoint(x: 512, y: 600), startRadius: 0,
                       endCenter: CGPoint(x: 512, y: 600), endRadius: 430, options: [])

// Ground shadow under the pin tip.
ctx.saveGState()
ctx.setFillColor(rgb(0, 0.1, 0.3, 0.28))
ctx.setShadow(offset: .zero, blur: 24, color: rgb(0, 0.1, 0.3, 0.5))
ctx.fillEllipse(in: CGRect(x: 512 - 120, y: 180 - 26, width: 240, height: 52))
ctx.restoreGState()

// Pin: head circle plus tangent lines down to a slightly rounded tip.
let center = CGPoint(x: 512, y: 600)
let r = 255.0
let tip = CGPoint(x: 512, y: 200)
let d = center.y - tip.y
let spread = acos(r / d)                        // angle between center→tip and center→tangent point
let right = -Double.pi / 2 + spread
let left = -Double.pi / 2 - spread
let pin = CGMutablePath()
pin.move(to: CGPoint(x: center.x + r * cos(right), y: center.y + r * sin(right)))
pin.addArc(center: center, radius: r, startAngle: right, endAngle: left + 2 * .pi, clockwise: false)
pin.addArc(tangent1End: tip, tangent2End: CGPoint(x: center.x + r * cos(right), y: center.y + r * sin(right)),
           radius: 28)
pin.closeSubpath()

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 40, color: rgb(0, 0.12, 0.35, 0.45))
ctx.addPath(pin)
ctx.setFillColor(rgb(1, 1, 1))
ctx.fillPath()
ctx.restoreGState()

// Open book inside the pin head.
let blue = rgb(0.02, 0.43, 1.0)
let bookCenter = CGPoint(x: 512, y: 592)
let pageW = 150.0, pageH = 172.0, gap = 10.0, sag = 24.0

func page(_ side: Double) -> CGPath {
    // side = -1 for left, +1 for right
    let inner = bookCenter.x + side * gap
    let outer = bookCenter.x + side * (gap + pageW)
    let bottom = bookCenter.y - pageH / 2
    let top = bookCenter.y + pageH / 2
    let p = CGMutablePath()
    p.move(to: CGPoint(x: inner, y: bottom))
    // bottom edge dips toward the spine
    p.addQuadCurve(to: CGPoint(x: outer, y: bottom + sag),
                   control: CGPoint(x: (inner + outer) / 2, y: bottom + sag * 0.15))
    p.addLine(to: CGPoint(x: outer, y: top + sag))
    // top edge rises from the spine, like pages fanning open
    p.addQuadCurve(to: CGPoint(x: inner, y: top),
                   control: CGPoint(x: (inner + outer) / 2, y: top + sag * 0.15))
    p.closeSubpath()
    return p
}

ctx.setFillColor(blue)
ctx.addPath(page(-1)); ctx.fillPath()
ctx.addPath(page(1)); ctx.fillPath()

// Text lines on each page, in white.
ctx.setStrokeColor(rgb(1, 1, 1, 0.9))
ctx.setLineWidth(9)
ctx.setLineCap(.round)
for side in [-1.0, 1.0] {
    for i in 0..<3 {
        let y = bookCenter.y + 44 - Double(i) * 44
        let a = bookCenter.x + side * (gap + 30)
        let b = bookCenter.x + side * (gap + pageW - 26)
        let lift = sag * 0.55
        let line = CGMutablePath()
        line.move(to: CGPoint(x: a, y: y + 4))
        line.addQuadCurve(to: CGPoint(x: b, y: y + lift), control: CGPoint(x: (a + b) / 2, y: y + 4))
        ctx.addPath(line)
    }
}
ctx.strokePath()

// Small gold star at the upper right of the pin head: ratings.
func star(center c: CGPoint, outer: Double, inner: Double) -> CGPath {
    let p = CGMutablePath()
    for i in 0..<10 {
        let rad = i.isMultiple(of: 2) ? outer : inner
        let a = Double.pi / 2 + Double(i) * .pi / 5
        let pt = CGPoint(x: c.x + rad * cos(a), y: c.y + rad * sin(a))
        i == 0 ? p.move(to: pt) : p.addLine(to: pt)
    }
    p.closeSubpath()
    return p
}
let starCenter = CGPoint(x: 512 + r * cos(.pi / 4) + 6, y: 600 + r * sin(.pi / 4) + 6)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 16, color: rgb(0, 0.1, 0.3, 0.4))
ctx.setFillColor(rgb(1, 1, 1))
ctx.fillEllipse(in: CGRect(x: starCenter.x - 82, y: starCenter.y - 82, width: 164, height: 164))
ctx.restoreGState()
ctx.addPath(star(center: starCenter, outer: 62, inner: 27))
ctx.setFillColor(rgb(1.0, 0.74, 0.12))
ctx.fillPath()

let image = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: image)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
