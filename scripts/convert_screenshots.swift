import Foundation
import AppKit
import CoreGraphics

func processImage(inputPath: String, outputPath: String) {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: inputPath)),
          let originalRep = NSBitmapImageRep(data: data),
          let cgImage = originalRep.cgImage else {
        print("❌ Failed to load original image: \(inputPath)")
        return
    }
    
    let targetWidth = 2064
    let targetHeight = 2752
    
    let pixelWidth = originalRep.pixelsWide
    let pixelHeight = originalRep.pixelsHigh
    
    print("📷 Processing iPhone to iPad SS: \(inputPath) (\(pixelWidth)x\(pixelHeight))")
    
    // Scale factor to fit height
    let scale = CGFloat(targetHeight) / CGFloat(pixelHeight)
    let newWidth = CGFloat(pixelWidth) * scale
    let newHeight = CGFloat(targetHeight)
    
    // Sample background color (from top-left pixel)
    var backgroundColor = NSColor.black
    if let color = originalRep.colorAt(x: 10, y: 10) {
        if let srgbColor = color.usingColorSpace(.sRGB) {
            backgroundColor = srgbColor
        } else {
            backgroundColor = color
        }
    }
    
    print("🎨 Sampled background color: R:\(backgroundColor.redComponent) G:\(backgroundColor.greenComponent) B:\(backgroundColor.blueComponent)")
    
    // Create CGContext without alpha channel (noneSkipLast)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let cgContext = CGContext(
        data: nil,
        width: targetWidth,
        height: targetHeight,
        bitsPerComponent: 8,
        bytesPerRow: targetWidth * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else {
        print("❌ Failed to create CGContext")
        return
    }
    
    // Fill background
    cgContext.setFillColor(backgroundColor.cgColor)
    cgContext.fill(CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
    
    // Draw original image centered
    let xOffset = (CGFloat(targetWidth) - newWidth) / 2.0
    let drawRect = CGRect(x: xOffset, y: 0, width: newWidth, height: newHeight)
    cgContext.draw(cgImage, in: drawRect)
    
    // Create new CGImage from context
    guard let newCgImage = cgContext.makeImage() else {
        print("❌ Failed to create new CGImage")
        return
    }
    
    // Create NSBitmapImageRep from CGImage
    let newRep = NSBitmapImageRep(cgImage: newCgImage)
    
    // Export to PNG
    guard let pngData = newRep.representation(using: NSBitmapImageRep.FileType.png, properties: [:]) else {
        print("❌ Failed to generate PNG representation")
        return
    }
    
    do {
        try pngData.write(to: URL(fileURLWithPath: outputPath))
        print("✅ Converted to: \(outputPath) (\(targetWidth)x\(targetHeight))")
    } catch {
        print("❌ Failed to write file: \(error)")
    }
}

// Get files from ios-ss directory
let fileManager = FileManager.default
let currentDir = fileManager.currentDirectoryPath
let iosSsDir = "\(currentDir)/ios-ss"
let ipadSsDir = "\(currentDir)/ipad-ss"

// Create ipad-ss directory if it doesn't exist
if !fileManager.fileExists(atPath: ipadSsDir) {
    do {
        try fileManager.createDirectory(atPath: ipadSsDir, withIntermediateDirectories: true, attributes: nil)
        print("📁 Created directory: \(ipadSsDir)")
    } catch {
        print("❌ Failed to create directory: \(error)")
        exit(1)
    }
}

do {
    let files = try fileManager.contentsOfDirectory(atPath: iosSsDir)
    let pngFiles = files.filter { $0.hasSuffix(".png") }.sorted()
    
    if pngFiles.isEmpty {
        print("No PNG screenshots found in \(iosSsDir)")
    } else {
        for file in pngFiles {
            let inputPath = "\(iosSsDir)/\(file)"
            // Note: If you want to run this, you can specify a different output path or keep it ipadSsDir
            let outputPath = "\(ipadSsDir)/\(file)"
            processImage(inputPath: inputPath, outputPath: outputPath)
        }
        print("🎉 Finished processing all screenshots successfully!")
    }
} catch {
    print("❌ Error reading directory: \(error)")
}
