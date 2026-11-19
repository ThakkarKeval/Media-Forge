import AVFoundation
import Foundation
import PhotosUI
import UIKit
import UniformTypeIdentifiers

final class MediaForgePicker: NSObject, MediaForgePickerApi {

  // MARK: - MediaForgePickerApi

  func pickImage(source: NativeMediaSource, options: NativePickerOptions?) async throws -> NativePickedMedia? {
    if source == .camera {
      return try await captureMedia(mediaType: .image, options: options)
    } else {
      let results = try await presentPHPicker(filter: .images, selectionLimit: 1)
      return results.first
    }
  }

  func pickVideo(source: NativeMediaSource, options: NativePickerOptions?) async throws -> NativePickedMedia? {
    if source == .camera {
      return try await captureMedia(mediaType: .video, options: options)
    } else {
      let results = try await presentPHPicker(filter: .videos, selectionLimit: 1)
      return results.first
    }
  }

  func pickMultiple(type: NativeMediaType, options: NativePickerOptions?) async throws -> [NativePickedMedia] {
    let filter: PHPickerFilter
    switch type {
    case .image:
      filter = .images
    case .video:
      filter = .videos
    case .mixed:
      filter = .any(of: [.images, .videos])
    }

    let limit = Int(options?.maxItems ?? 0)
    return try await presentPHPicker(filter: filter, selectionLimit: limit)
  }

  func retrieveLostData() async throws -> NativeLostDataResponse {
    // iOS does not destroy/recreate host activities during picker display.
    return NativeLostDataResponse(items: [])
  }

  // MARK: - PHPickerViewController Presentation

  @MainActor
  private func presentPHPicker(filter: PHPickerFilter, selectionLimit: Int) async throws -> [NativePickedMedia] {
    guard let rootViewController = topViewController() else {
      throw PigeonError(code: "no_view_controller", message: "Cannot find root view controller", details: nil)
    }

    return try await withCheckedThrowingContinuation { continuation in
      var configuration = PHPickerConfiguration()
      configuration.filter = filter
      configuration.selectionLimit = selectionLimit
      configuration.preferredAssetRepresentationMode = .current

      let picker = PHPickerViewController(configuration: configuration)
      let delegate = PHPickerDelegateHandler { results in
        Task {
          let mediaItems = await self.processPHPickerResults(results)
          continuation.resume(returning: mediaItems)
        }
      }
      picker.delegate = delegate
      objc_setAssociatedObject(picker, &AssociatedKeys.delegateKey, delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

      rootViewController.present(picker, animated: true)
    }
  }

  private func processPHPickerResults(_ results: [PHPickerResult]) async -> [NativePickedMedia] {
    var pickedItems: [NativePickedMedia] = []

    for result in results {
      let provider = result.itemProvider
      let isVideo = provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier)
      let typeIdentifier = isVideo ? UTType.movie.identifier : UTType.image.identifier

      if let media = await loadFileRepresentation(from: provider, typeIdentifier: typeIdentifier, isVideo: isVideo) {
        pickedItems.append(media)
      }
    }

    return pickedItems
  }

  private func loadFileRepresentation(
    from provider: NSItemProvider,
    typeIdentifier: String,
    isVideo: Bool
  ) async -> NativePickedMedia? {
    await withCheckedContinuation { continuation in
      provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { url, error in
        guard let sourceUrl = url, error == nil else {
          continuation.resume(returning: nil)
          return
        }

        let ext = sourceUrl.pathExtension.isEmpty ? (isVideo ? "mp4" : "jpg") : sourceUrl.pathExtension
        let prefix = isVideo ? "VID_" : "IMG_"
        let destUrl = self.createCacheUrl(prefix: prefix, ext: ext)

        do {
          if FileManager.default.fileExists(atPath: destUrl.path) {
            try FileManager.default.removeItem(at: destUrl)
          }
          try FileManager.default.copyItem(at: sourceUrl, to: destUrl)

          let media = self.inspectMediaFile(at: destUrl, isVideo: isVideo)
          continuation.resume(returning: media)
        } catch {
          continuation.resume(returning: nil)
        }
      }
    }
  }

  // MARK: - Camera Capture

  @MainActor
  private func captureMedia(mediaType: NativeMediaType, options: NativePickerOptions?) async throws -> NativePickedMedia? {
    guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
      throw PigeonError(code: "camera_unavailable", message: "Camera is not available on this device", details: nil)
    }
    guard let rootViewController = topViewController() else {
      throw PigeonError(code: "no_view_controller", message: "Cannot find root view controller", details: nil)
    }

    return try await withCheckedThrowingContinuation { continuation in
      let picker = UIImagePickerController()
      picker.sourceType = .camera

      if mediaType == .video {
        picker.mediaTypes = [UTType.movie.identifier]
        if let maxDuration = options?.maxDurationSeconds, maxDuration > 0 {
          picker.videoMaximumDuration = TimeInterval(maxDuration)
        }
      } else {
        picker.mediaTypes = [UTType.image.identifier]
      }

      if options?.cameraDevice == .front && UIImagePickerController.isCameraDeviceAvailable(.front) {
        picker.cameraDevice = .front
      } else {
        picker.cameraDevice = .rear
      }

      let delegate = CameraPickerDelegateHandler { media in
        continuation.resume(returning: media)
      }
      picker.delegate = delegate
      objc_setAssociatedObject(picker, &AssociatedKeys.delegateKey, delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

      rootViewController.present(picker, animated: true)
    }
  }

  // MARK: - Inspection & File Helpers

  func inspectMediaFile(at url: URL, isVideo: Bool) -> NativePickedMedia? {
    let path = url.path
    guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
          let fileSize = attributes[.size] as? Int64 else {
      return nil
    }

    let fileName = url.lastPathComponent
    let mimeType = getMimeType(for: url, isVideo: isVideo)

    if isVideo {
      let asset = AVURLAsset(url: url)
      let durationMs = Int64(CMTimeGetSeconds(asset.duration) * 1000)
      var width: Int64?
      var height: Int64?

      if let track = asset.tracks(withMediaType: .video).first {
        let size = track.naturalSize.applying(track.preferredTransform)
        width = Int64(abs(size.width))
        height = Int64(abs(size.height))
      }

      return NativePickedMedia(
        path: path,
        type: .video,
        name: fileName,
        mimeType: mimeType,
        sizeBytes: fileSize,
        width: width,
        height: height,
        durationMs: durationMs > 0 ? durationMs : nil
      )
    } else {
      var width: Int64?
      var height: Int64?

      if let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
         let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] {
        if let pixelWidth = properties[kCGImagePropertyPixelWidth] as? Int64 {
          width = pixelWidth
        }
        if let pixelHeight = properties[kCGImagePropertyPixelHeight] as? Int64 {
          height = pixelHeight
        }
      }

      return NativePickedMedia(
        path: path,
        type: .image,
        name: fileName,
        mimeType: mimeType,
        sizeBytes: fileSize,
        width: width,
        height: height,
        durationMs: nil
      )
    }
  }

  private func createCacheUrl(prefix: String, ext: String) -> URL {
    let cacheDir = FileManager.default.temporaryDirectory.appendingPathComponent("media_forge")
    if !FileManager.default.fileExists(atPath: cacheDir.path) {
      try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }
    let uniqueName = "\(prefix)\(UUID().uuidString).\(ext)"
    return cacheDir.appendingPathComponent(uniqueName)
  }

  private func getMimeType(for url: URL, isVideo: Bool) -> String {
    if let type = UTType(filenameExtension: url.pathExtension),
       let mime = type.preferredMIMEType {
      return mime
    }
    return isVideo ? "video/mp4" : "image/jpeg"
  }

  @MainActor
  private func topViewController() -> UIViewController? {
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let window = windowScene.windows.first(where: { $0.isKeyWindow }),
          var top = window.rootViewController else {
      return nil
    }
    while let presented = top.presentedViewController {
      top = presented
    }
    return top
  }
}

// MARK: - Delegate Handlers

private struct AssociatedKeys {
  static var delegateKey = "MediaForgePickerDelegateKey"
}

private final class PHPickerDelegateHandler: NSObject, PHPickerViewControllerDelegate {
  private let onFinish: ([PHPickerResult]) -> Void

  init(onFinish: @escaping ([PHPickerResult]) -> Void) {
    self.onFinish = onFinish
  }

  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    picker.dismiss(animated: true) {
      self.onFinish(results)
    }
  }
}

private final class CameraPickerDelegateHandler: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
  private let onFinish: (NativePickedMedia?) -> Void

  init(onFinish: @escaping (NativePickedMedia?) -> Void) {
    self.onFinish = onFinish
  }

  func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
    picker.dismiss(animated: true) {
      if let mediaUrl = info[.mediaURL] as? URL {
        let destUrl = FileManager.default.temporaryDirectory
          .appendingPathComponent("media_forge")
          .appendingPathComponent("VID_\(UUID().uuidString).mp4")
        try? FileManager.default.createDirectory(at: destUrl.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? FileManager.default.copyItem(at: mediaUrl, to: destUrl)
        let media = MediaForgePicker().inspectMediaFile(at: destUrl, isVideo: true)
        self.onFinish(media)
      } else if let image = info[.originalImage] as? UIImage,
                let data = image.jpegData(compressionQuality: 0.95) {
        let destUrl = FileManager.default.temporaryDirectory
          .appendingPathComponent("media_forge")
          .appendingPathComponent("IMG_\(UUID().uuidString).jpg")
        try? FileManager.default.createDirectory(at: destUrl.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: destUrl)
        let media = MediaForgePicker().inspectMediaFile(at: destUrl, isVideo: false)
        self.onFinish(media)
      } else {
        self.onFinish(nil)
      }
    }
  }

  func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
    picker.dismiss(animated: true) {
      self.onFinish(nil)
    }
  }
}
