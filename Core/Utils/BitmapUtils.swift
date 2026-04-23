import Foundation
import UIKit
import CoreImage

// MARK: - 图片工具

enum BitmapUtils {

    private static let ciContext = CIContext(options: nil)

    // MARK: 解码

    static func decodeBitmap(path: String, width: Int, height: Int? = nil) -> UIImage? {
        guard let image = UIImage(contentsOfFile: path) else { return nil }
        let targetHeight = CGFloat(height ?? Int(CGFloat(width) * image.size.height / max(image.size.width, 1)))
        return resize(image: image, to: CGSize(width: CGFloat(width), height: targetHeight))
    }

    static func decodeBitmap(path: String) -> UIImage? {
        UIImage(contentsOfFile: path)
    }

    static func decodeBitmap(data: Data, width: Int, height: Int? = nil) -> UIImage? {
        guard let image = UIImage(data: data) else { return nil }
        let targetHeight = CGFloat(height ?? Int(CGFloat(width) * image.size.height / max(image.size.width, 1)))
        return resize(image: image, to: CGSize(width: CGFloat(width), height: targetHeight))
    }

    // MARK: 变换

    static func resize(image: UIImage, to size: CGSize) -> UIImage? {
        guard size.width > 0, size.height > 0 else { return image }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    static func toInputStream(_ image: UIImage, compressionQuality: CGFloat = 0.9) -> InputStream? {
        guard let data = image.jpegData(compressionQuality: compressionQuality) else { return nil }
        return InputStream(data: data)
    }

    static func stackBlur(_ image: UIImage, radius: Double = 8) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return image }
        guard let filter = CIFilter(name: "CIGaussianBlur", parameters: [
            kCIInputImageKey: ciImage,
            kCIInputRadiusKey: NSNumber(value: Float(radius))
        ]) else { return image }
        guard let output = filter.outputImage,
              let cgImage = ciContext.createCGImage(output, from: ciImage.extent) else {
            return image
        }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }

    static func meanColor(_ image: UIImage) -> UIColor? {
        guard let ciImage = CIImage(image: image) else { return nil }

        let extent = CIVector(x: ciImage.extent.origin.x, y: ciImage.extent.origin.y, z: ciImage.extent.size.width, w: ciImage.extent.size.height)
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: ciImage, kCIInputExtentKey: extent]),
              let outputImage = filter.outputImage else {
            return nil
        }

        var bitmap = [UInt8](repeating: 0, count: 4)
        ciContext.render(outputImage,
                         toBitmap: &bitmap,
                         rowBytes: 4,
                         bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                         format: .RGBA8,
                         colorSpace: CGColorSpaceCreateDeviceRGB())

        return UIColor(
            red: CGFloat(bitmap[0]) / 255.0,
            green: CGFloat(bitmap[1]) / 255.0,
            blue: CGFloat(bitmap[2]) / 255.0,
            alpha: CGFloat(bitmap[3]) / 255.0
        )
    }
}
