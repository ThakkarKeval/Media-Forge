import CoreGraphics
import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

final class MediaForgeProcessor: NSObject, MediaForgeProcessorApi {

  func processImage(path: String, options: NativeImageProcessOptions) async throws -> NativeProcessedMedia {
    let sourceUrl = URL(fileURLWithPath: path)
    guard FileManager.default.fileExists(atPath: sourceUrl.path) else {
      throw PigeonError(code: "file_not_found", message: "Source image file does not exist: \(path)", details: nil)
    }

    guard let attributes = try? FileManager.default.attributesOfItem(atPath: sourceUrl.path),
          let originalSizeBytes = attributes[.size] as? Int64 else {
      throw PigeonError(code: "invalid_file", message: "Failed to read attributes for: \(path)", details: nil)
    }

    guard let imageSource = CGImageSourceCreateWithURL(sourceUrl as CFURL, nil) else {
      throw PigeonError(code: "invalid_image", message: "Failed to decode image from: \(path)", details: nil)
    }

    guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
          let origWidth = properties[kCGImagePropertyPixelWidth] as? Int,
          let origHeight = properties[kCGImagePropertyPixelHeight] as? Int else {
      throw PigeonError(code: "invalid_image", message: "Failed to inspect image dimensions from: \(path)", details: nil)
    }

    let orientation = properties[kCGImagePropertyOrientation] as? UInt32 ?? 1
    let isRotated90 = (orientation == 5 || orientation == 6 || orientation == 7 || orientation == 8)
    let orientedWidth = isRotated90 ? origHeight : origWidth
    let orientedHeight = isRotated90 ? origWidth : origHeight

    // Calculate target bounds
    let (finalWidth, finalHeight) = calculateTargetDimensions(
      srcWidth: orientedWidth,
      srcHeight: orientedHeight,
      maxWidth: options.maxWidth != nil ? Int(options.maxWidth!) : nil,
      maxHeight: options.maxHeight != nil ? Int(options.maxHeight!) : nil
    )

    let maxPixelSize = max(finalWidth, finalHeight)

    // Downsample and normalize orientation using ImageIO thumbnailing
    let thumbnailOptions: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
      kCGImageSourceShouldCache: false
    ]

    guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, thumbnailOptions as CFDictionary) else {
      throw PigeonError(code: "processing_failed", message: "Failed to downsample image: \(path)", details: nil)
    }

    var uiImage = UIImage(cgImage: downsampledImage)

    // Determine target format
    let targetFormat = options.format?.lowercased() ?? (sourceUrl.pathExtension.lowercased() == "png" ? "png" : "jpeg")
    let isPng = targetFormat == "png"
    let targetExt = isPng ? "png" : "jpg"
    let targetMime = isPng ? "image/png" : "image/jpeg"

    // If converting a transparent image to JPEG, composite onto white background
    if !isPng && hasAlpha(cgImage: downsampledImage) {
      let renderer = UIGraphicsImageRenderer(size: uiImage.size)
      uiImage = renderer.image { ctx in
        UIColor.white.setFill()
        ctx.fill(CGRect(origin: .zero, size: uiImage.size))
        uiImage.draw(at: .zero)
      }
    }

    // Compression and target size search
    let targetBytes = options.targetSizeBytes
    let initialQuality = CGFloat(options.quality ?? 85) / 100.0

    let (compressedData, targetMet) = try compressImage(
      image: uiImage,
      isPng: isPng,
      initialQuality: initialQuality,
      targetBytes: targetBytes
    )

    // Write output file
    let destUrl = createCacheUrl(prefix: "PROC_", ext: targetExt)
    try compressedData.write(to: destUrl)

    // Copy EXIF metadata while stripping GPS if requested
    let stripGps = options.stripGpsMetadata ?? true
    copyExifMetadata(from: sourceUrl, to: destUrl, stripGps: stripGps)

    let outputSizeBytes = (try? FileManager.default.attributesOfItem(atPath: destUrl.path)[.size] as? Int64) ?? Int64(compressedData.count)

    return NativeProcessedMedia(
      path: destUrl.path,
      originalPath: sourceUrl.path,
      mimeType: targetMime,
      sizeBytes: outputSizeBytes,
      originalSizeBytes: originalSizeBytes,
      width: Int64(uiImage.size.width),
      height: Int64(uiImage.size.height),
      changed: true,
      targetMet: targetMet
    )
  }

  func inspectVideo(path: String) async throws -> NativeVideoMetadata {
    throw PigeonError(code: "unimplemented", message: "inspectVideo is part of Milestone 3", details: nil)
  }

  func createVideoThumbnail(videoPath: String, atMs: Int64, maxWidth: Int64?, maxHeight: Int64?) async throws -> String {
    throw PigeonError(code: "unimplemented", message: "createVideoThumbnail is part of Milestone 3", details: nil)
  }

  func clearCache() async throws -> Bool {
    let cacheDir = FileManager.default.temporaryDirectory.appendingPathComponent("media_forge")
    if FileManager.default.fileExists(atPath: cacheDir.path) {
      let contents = try? FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil)
      contents?.forEach { fileUrl in
        try? FileManager.default.removeItem(at: fileUrl)
      }
    }
    return true
  }

  // MARK: - Helpers

  private func calculateTargetDimensions(
    srcWidth: Int,
    srcHeight: Int,
    maxWidth: Int?,
    maxHeight: Int?
  ) -> (Int, Int) {
    if maxWidth == nil && maxHeight == nil {
      return (srcWidth, srcHeight)
    }

    let widthRatio = maxWidth != nil ? CGFloat(maxWidth!) / CGFloat(srcWidth) : CGFloat.greatestFiniteMagnitude
    let heightRatio = maxHeight != nil ? CGFloat(maxHeight!) / CGFloat(srcHeight) : CGFloat.greatestFiniteMagnitude
    let scale = min(widthRatio, heightRatio)

    if scale < 1.0 {
      let w = max(1, Int((CGFloat(srcWidth) * scale).rounded()))
      let h = max(1, Int((CGFloat(srcHeight) * scale).rounded()))
      return (w, h)
    }

    return (srcWidth, srcHeight)
  }

  private func hasAlpha(cgImage: CGImage) -> Bool {
    let alphaInfo = cgImage.alphaInfo
    return alphaInfo == .first ||
           alphaInfo == .last ||
           alphaInfo == .premultipliedFirst ||
           alphaInfo == .premultipliedLast
  }

  private func compressImage(
    image: UIImage,
    isPng: Bool,
    initialQuality: CGFloat,
    targetBytes: Int64?
  ) throws -> (Data, Bool?) {
    if isPng {
      guard let data = image.pngData() else {
        throw PigeonError(code: "encoding_failed", message: "Failed to encode PNG image", details: nil)
      }
      return (data, nil)
    }

    if let target = targetBytes, target > 0 {
      var low: CGFloat = 0.1
      var high: CGFloat = min(1.0, max(0.1, initialQuality))
      var bestData: Data?

      for _ in 0..<5 {
        let mid = (low + high) / 2.0
        if let data = image.jpegData(compressionQuality: mid) {
          if Int64(data.count) <= target {
            bestData = data
            low = mid + 0.05
          } else {
            high = mid - 0.05
            if bestData == nil || data.count < bestData!.count {
              bestData = data
            }
          }
        }
        if low > high { break }
      }

      let finalData = bestData ?? image.jpegData(compressionQuality: low) ?? Data()
      let targetMet = Int64(finalData.count) <= target
      return (finalData, targetMet)
    } else {
      guard let data = image.jpegData(compressionQuality: initialQuality) else {
        throw PigeonError(code: "encoding_failed", message: "Failed to encode JPEG image", details: nil)
      }
      return (data, nil)
    }
  }

  private func copyExifMetadata(from sourceUrl: URL, to destUrl: URL, stripGps: Bool) {
    guard let source = CGImageSourceCreateWithURL(sourceUrl as CFURL, nil),
          var properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
      return
    }

    if stripGps {
      properties.removeValue(forKey: kCGImagePropertyGPSDictionary)
    }

    guard let image = UIImage(contentsOfFile: destUrl.path),
          let destination = CGImageDestinationCreateWithURL(destUrl as CFURL, UTType.jpeg.identifier as CFString, 1, nil),
          let cgImage = image.cgImage else {
      return
    }

    CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
    CGImageDestinationFinalize(destination)
  }

  private func createCacheUrl(prefix: String, ext: String) -> URL {
    let cacheDir = FileManager.default.temporaryDirectory.appendingPathComponent("media_forge")
    if !FileManager.default.fileExists(atPath: cacheDir.path) {
      try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }
    return cacheDir.appendingPathComponent("\(prefix)\(UUID().uuidString).\(ext)")
  }
}
