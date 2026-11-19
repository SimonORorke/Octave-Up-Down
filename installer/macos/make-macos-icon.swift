import AppKit
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

var temporaryIconset: URL?

func fail(_ message: String) -> Never {
    if let temporaryIconset = temporaryIconset {
        try? FileManager.default.removeItem(at: temporaryIconset)
    }
    FileHandle.standardError.write(Data("Error: \(message)\n".utf8))
    exit(1)
}

guard CommandLine.arguments.count == 3 else {
    fail("Usage: swift make-macos-icon.swift input.png output.icns")
}

let input = URL(fileURLWithPath: CommandLine.arguments[1]).standardizedFileURL
let output = URL(fileURLWithPath: CommandLine.arguments[2]).standardizedFileURL
let files = FileManager.default
guard output.pathExtension.lowercased() == "icns" else {
    fail("The output filename must end in .icns")
}
guard !files.fileExists(atPath: output.path) else {
    fail("Output already exists: \(output.path). Choose another filename to avoid overwriting it.")
}
guard let source = CGImageSourceCreateWithURL(input as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    fail("Cannot read the input image: \(input.path)")
}
guard image.width == image.height else {
    fail("The input image must be square; got \(image.width)×\(image.height).")
}

let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
func canvas(_ size: Int) -> CGContext {
    guard let context = CGContext(data: nil, width: size, height: size,
                                  bitsPerComponent: 8, bytesPerRow: 0,
                                  space: colorSpace,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        fail("Cannot create a \(size)×\(size) canvas.")
    }
    context.interpolationQuality = .high
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    return context
}

// The 824-pixel tile and 100-pixel margins follow the common macOS icon grid.
let master = canvas(1024)
let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
let outline = RoundedRectangle(cornerRadius: 824 * 0.2237, style: .continuous).path(in: tile)
master.addPath(outline.cgPath)
master.clip()
master.draw(image, in: tile)
guard let masterImage = master.makeImage() else { fail("Cannot render the icon.") }

let iconset = output.deletingLastPathComponent()
    .appendingPathComponent(".macos-icon-\(UUID().uuidString).iconset", isDirectory: true)
do {
    try files.createDirectory(at: iconset, withIntermediateDirectories: false)
} catch {
    fail("Cannot create temporary iconset: \(error.localizedDescription)")
}
temporaryIconset = iconset
defer { try? files.removeItem(at: iconset) }

let variants: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024)
]
for (name, size) in variants {
    let context = canvas(size)
    context.draw(masterImage, in: CGRect(x: 0, y: 0, width: size, height: size))
    guard let variant = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(
            iconset.appendingPathComponent(name) as CFURL, UTType.png.identifier as CFString, 1, nil
          ) else { fail("Cannot create \(name).") }
    CGImageDestinationAddImage(destination, variant, nil)
    guard CGImageDestinationFinalize(destination) else { fail("Cannot write \(name).") }
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", output.path]
do {
    try iconutil.run()
    iconutil.waitUntilExit()
} catch {
    fail("Cannot run iconutil: \(error.localizedDescription)")
}
guard iconutil.terminationStatus == 0 else { fail("iconutil failed.") }
print("Created \(output.path)")