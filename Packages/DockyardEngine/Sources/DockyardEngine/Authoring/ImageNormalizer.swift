import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Redraws an image at a fixed square size as PNG.
///
/// Catalog icons are fetched and cached by URL, so shipping whatever size the
/// author happened to pick would leave the app scaling it at display time. Using
/// ImageIO rather than AppKit keeps this usable from anywhere in the engine.
enum ImageNormalizer {

    static func pngData(from source: URL, size: Int) throws -> Data {
        guard let imageSource = CGImageSourceCreateWithURL(source as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            throw DockyardFolderError.unreadableImage(source.path)
        }

        guard let context = CGContext(
            data: nil,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw DockyardFolderError.unreadableImage(source.path)
        }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))

        guard let scaled = context.makeImage() else {
            throw DockyardFolderError.unreadableImage(source.path)
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw DockyardFolderError.unreadableImage(source.path)
        }
        CGImageDestinationAddImage(destination, scaled, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw DockyardFolderError.unreadableImage(source.path)
        }
        return data as Data
    }
}
