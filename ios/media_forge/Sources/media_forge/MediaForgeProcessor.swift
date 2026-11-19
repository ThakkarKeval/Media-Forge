import AVFoundation
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
    let rawFormat = options.format?.lowercased()
    let isHeic = rawFormat == "heic" || rawFormat == "heif"
    let isPng = rawFormat == "png" || (rawFormat == nil && sourceUrl.pathExtension.lowercased() == "png")
    let targetExt = isHeic ? "heic" : (isPng ? "png" : "jpg")
    let targetMime = isHeic ? "image/heic" : (isPng ? "image/png" : "image/jpeg")

    // If converting a transparent image to JPEG, composite onto white background
    if !isPng && !isHeic && hasAlpha(cgImage: downsampledImage) {
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
      isHeic: isHeic,
      initialQuality: initialQuality,
      targetBytes: targetBytes
    )

    // Write output file
    let destUrl = createCacheUrl(prefix: "PROC_", ext: targetExt, customName: options.outputFileName)
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
    let url = URL(fileURLWithPath: path)
    guard FileManager.default.fileExists(atPath: url.path) else {
      throw PigeonError(code: "file_not_found", message: "Video file does not exist: \(path)", details: nil)
    }

    let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
    let sizeBytes = attributes?[.size] as? Int64

    let asset = AVURLAsset(url: url)
    let durationSeconds = CMTimeGetSeconds(asset.duration)
    let durationMs: Int64? = durationSeconds.isFinite ? Int64(durationSeconds * 1000.0) : nil

    var width: Int64?
    var height: Int64?
    var rotationDegrees: Int64 = 0

    if let track = asset.tracks(withMediaType: .video).first {
      let naturalSize = track.naturalSize
      let transform = track.preferredTransform

      // Determine rotation from transform matrix
      if transform.a == 0 && transform.b == 1.0 && transform.c == -1.0 && transform.d == 0 {
        rotationDegrees = 90
      } else if transform.a == -1.0 && transform.b == 0 && transform.c == 0 && transform.d == -1.0 {
        rotationDegrees = 180
      } else if transform.a == 0 && transform.b == -1.0 && transform.c == 1.0 && transform.d == 0 {
        rotationDegrees = 270
      } else {
        rotationDegrees = 0
      }

      let isRotated90 = (rotationDegrees == 90 || rotationDegrees == 270)
      let orientedW = isRotated90 ? naturalSize.height : naturalSize.width
      let orientedH = isRotated90 ? naturalSize.width : naturalSize.height

      width = Int64(orientedW)
      height = Int64(orientedH)
    }

    let ext = url.pathExtension.lowercased()
    let mimeType = ext == "mov" ? "video/quicktime" : "video/mp4"

    return NativeVideoMetadata(
      path: url.path,
      mimeType: mimeType,
      sizeBytes: sizeBytes,
      width: width,
      height: height,
      durationMs: durationMs,
      rotationDegrees: rotationDegrees
    )
  }

  func createVideoThumbnail(videoPath: String, atMs: Int64, maxWidth: Int64?, maxHeight: Int64?) async throws -> String {
    let url = URL(fileURLWithPath: videoPath)
    guard FileManager.default.fileExists(atPath: url.path) else {
      throw PigeonError(code: "file_not_found", message: "Video file does not exist: \(videoPath)", details: nil)
    }

    let asset = AVURLAsset(url: url)
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true

    if let mw = maxWidth, let mh = maxHeight {
      generator.maximumSize = CGSize(width: CGFloat(mw), height: CGFloat(mh))
    } else if let mw = maxWidth {
      generator.maximumSize = CGSize(width: CGFloat(mw), height: CGFloat.greatestFiniteMagnitude)
    } else if let mh = maxHeight {
      generator.maximumSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat(mh))
    }

    let timeSeconds = max(0.0, Double(atMs) / 1000.0)
    let cmTime = CMTime(seconds: timeSeconds, preferredTimescale: 600)

    let cgImage: CGImage
    do {
      cgImage = try generator.copyCGImage(at: cmTime, actualTime: nil)
    } catch {
      throw PigeonError(code: "thumbnail_failed", message: "Failed to extract thumbnail: \(error.localizedDescription)", details: nil)
    }

    let uiImage = UIImage(cgImage: cgImage)
    guard let jpegData = uiImage.jpegData(compressionQuality: 0.85) else {
      throw PigeonError(code: "encoding_failed", message: "Failed to encode thumbnail as JPEG", details: nil)
    }

    let destUrl = createCacheUrl(prefix: "THUMB_", ext: "jpg")
    try jpegData.write(to: destUrl)

    return destUrl.path
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
    isHeic: Bool = false,
    initialQuality: CGFloat,
    targetBytes: Int64?
  ) throws -> (Data, Bool?) {
    if isPng {
      guard let data = image.pngData() else {
        throw PigeonError(code: "encoding_failed", message: "Failed to encode PNG image", details: nil)
      }
      return (data, nil)
    }

    if isHeic {
      let data = NSMutableData()
      guard let destination = CGImageDestinationCreateWithData(data as CFMutableData, UTType.heic.identifier as CFString, 1, nil),
            let cgImage = image.cgImage else {
        // Fallback to JPEG if HEIC encoder is unavailable
        guard let jpegData = image.jpegData(compressionQuality: initialQuality) else {
          throw PigeonError(code: "encoding_failed", message: "Failed to encode image", details: nil)
        }
        return (jpegData, nil)
      }

      let options: [CFString: Any] = [
        kCGImageDestinationLossyCompressionQuality: initialQuality
      ]
      CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
      if CGImageDestinationFinalize(destination) {
        return (data as Data, targetBytes != nil ? Int64(data.count) <= targetBytes! : nil)
      }
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

  private func createCacheUrl(prefix: String, ext: String, customName: String? = nil) -> URL {
    let cacheDir = FileManager.default.temporaryDirectory.appendingPathComponent("media_forge")
    if !FileManager.default.fileExists(atPath: cacheDir.path) {
      try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    let baseName: String
    if let custom = customName, !custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      baseName = custom.trimmingCharacters(in: .whitespacesAndNewlines)
    } else {
      baseName = "media_forge_opt_\(Int(Date().timeIntervalSince1970 * 1000))"
    }

    var sanitized = baseName
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "\\", with: "_")
      .replacingOccurrences(of: ":", with: "_")

    let dotExt = ".\(ext)"
    if !sanitized.lowercased().hasSuffix(dotExt.lowercased()) {
      sanitized = "\(sanitized)\(dotExt)"
    }
    return cacheDir.appendingPathComponent(sanitized)
  }
}
