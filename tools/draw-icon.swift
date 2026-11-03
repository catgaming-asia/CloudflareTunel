// Draws Resources/AppIcon.png (1024×1024): orange squircle, white cloud, tunnel arch with a port arrow.
// swift tools/draw-icon.swift && sips -z 1024 1024 Resources/AppIcon.png  (Retina screens render at 2×)
import AppKit

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext

// macOS icon grid: 824pt body centred, 185pt corner radius, soft drop shadow.
let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let squircle = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: NSColor.black.withAlphaComponent(0.35).cgColor)
ctx.addPath(squircle)
ctx.setFillColor(NSColor.black.cgColor)
ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(squircle)
ctx.clip()
let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                          colors: [NSColor(srgbRed: 1.00, green: 0.71, blue: 0.27, alpha: 1).cgColor,
                                   NSColor(srgbRed: 0.96, green: 0.42, blue: 0.10, alpha: 1).cgColor] as CFArray,
                          locations: [0, 1])!
ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: body.maxY), end: CGPoint(x: 0, y: body.minY), options: [])

// Cloud: three bumps on a flat base.
let cloud = CGMutablePath()
cloud.addEllipse(in: CGRect(x: 230, y: 420, width: 260, height: 260))
cloud.addEllipse(in: CGRect(x: 370, y: 480, width: 330, height: 330))
cloud.addEllipse(in: CGRect(x: 580, y: 420, width: 230, height: 230))
cloud.addRoundedRect(in: CGRect(x: 230, y: 420, width: 580, height: 150), cornerWidth: 75, cornerHeight: 75)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: NSColor(srgbRed: 0.6, green: 0.2, blue: 0, alpha: 0.35).cgColor)
ctx.addPath(cloud)
ctx.setFillColor(NSColor.white.cgColor)
ctx.fillPath()
ctx.restoreGState()

// Tunnel arch cut into the cloud base.
let arch = CGMutablePath()
arch.move(to: CGPoint(x: 400, y: 420))
arch.addLine(to: CGPoint(x: 400, y: 520))
arch.addArc(center: CGPoint(x: 520, y: 520), radius: 120, startAngle: .pi, endAngle: 0, clockwise: true)
arch.addLine(to: CGPoint(x: 640, y: 420))
arch.closeSubpath()
ctx.addPath(arch)
ctx.setFillColor(NSColor(srgbRed: 0.20, green: 0.12, blue: 0.10, alpha: 1).cgColor)
ctx.fillPath()

// Road out of the tunnel to the bottom edge, with an arrow pointing out.
let road = CGMutablePath()
road.move(to: CGPoint(x: 400, y: 420))
road.addLine(to: CGPoint(x: 640, y: 420))
road.addLine(to: CGPoint(x: 720, y: 100))
road.addLine(to: CGPoint(x: 320, y: 100))
road.closeSubpath()
ctx.addPath(road)
ctx.setFillColor(NSColor(srgbRed: 0.20, green: 0.12, blue: 0.10, alpha: 0.85).cgColor)
ctx.fillPath()

let arrow = CGMutablePath()
arrow.move(to: CGPoint(x: 520, y: 470))
arrow.addLine(to: CGPoint(x: 590, y: 380))
arrow.addLine(to: CGPoint(x: 548, y: 380))
arrow.addLine(to: CGPoint(x: 556, y: 200))
arrow.addLine(to: CGPoint(x: 484, y: 200))
arrow.addLine(to: CGPoint(x: 492, y: 380))
arrow.addLine(to: CGPoint(x: 450, y: 380))
arrow.closeSubpath()
// Arrow points up: traffic from the port goes up into the cloud.
ctx.addPath(arrow)
ctx.setFillColor(NSColor(srgbRed: 1.00, green: 0.78, blue: 0.35, alpha: 1).cgColor)
ctx.fillPath()
ctx.restoreGState()

image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Resources/AppIcon.png")
try! rep.representation(using: .png, properties: [:])!.write(to: out)
print("Wrote \(out.path) \(rep.pixelsWide)×\(rep.pixelsHigh)")
