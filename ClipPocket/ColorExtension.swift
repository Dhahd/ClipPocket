//
//  File.swift
//  ClipPocket
//
//  Created by Shaneen on 10/14/24.
//



// Extension to create Color from NSImage

import CoreImage


extension Color {
    init(vibrantColorFrom image: NSImage) {
        let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)!
        let inputImage = CIImage(cgImage: cgImage)
        let extentVector = CIVector(x: inputImage.extent.origin.x, y: inputImage.extent.origin.y, z: inputImage.extent.size.width, w: inputImage.extent.size.height)

        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: inputImage, kCIInputExtentKey: extentVector]) else {
            self.init(.blue) // Fallback color
            return
        }
        guard let outputImage = filter.outputImage else {
            self.init(.blue) // Fallback color
            return
        }

        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull!])
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)

        // Convert to HSB
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        NSColor(red: CGFloat(bitmap[0]) / 255, green: CGFloat(bitmap[1]) / 255, blue: CGFloat(bitmap[2]) / 255, alpha: 1).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil)

        // Adjust HSB values for more vibrant colors
        saturation = min(saturation * 1.7, 1.0)  // Increase saturation by 70%
        brightness = min(brightness * 1.3, 1.0)  // Increase brightness by 30%

        // Convert back to RGB
        let color = NSColor(hue: hue, saturation: saturation, brightness: brightness, alpha: 1)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: nil)

        // Set the final color
        self.init(red: Double(red), green: Double(green), blue: Double(blue))
    }
}

extension NSColor {
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0
        
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
