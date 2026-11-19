import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_forge/media_forge.dart';
import 'package:media_forge/media_forge_pigeon.dart';
import 'package:media_forge/src/messages.g.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeMediaForgePickerApi fakePickerApi;
  late PigeonMediaForge pigeonPlatform;

  setUp(() {
    fakePickerApi = FakeMediaForgePickerApi();
    pigeonPlatform = PigeonMediaForge(pickerApi: fakePickerApi);
    MediaForgePlatform.instance = pigeonPlatform;
  });

  group('MediaPicker', () {
    test('pickImage returns PickedMedia on success', () async {
      fakePickerApi.nextPickedImage = NativePickedMedia(
        path: '/tmp/photo.jpg',
        type: NativeMediaType.image,
        name: 'photo.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 2048,
        width: 1024,
        height: 768,
      );

      final result = await MediaPicker.pickImage(source: MediaSource.gallery);

      expect(result, isNotNull);
      expect(result!.path, '/tmp/photo.jpg');
      expect(result.type, MediaType.image);
      expect(result.name, 'photo.jpg');
      expect(result.mimeType, 'image/jpeg');
      expect(result.sizeBytes, 2048);
      expect(result.width, 1024);
      expect(result.height, 768);
      expect(result.isImage, isTrue);
      expect(result.isVideo, isFalse);
    });

    test(
      'pickImage returns null on user cancellation without throwing',
      () async {
        fakePickerApi.nextPickedImage = null;

        final result = await MediaPicker.pickImage(source: MediaSource.gallery);
        expect(result, isNull);
      },
    );

    test(
      'pickImage throws MediaForgeException when validation fails',
      () async {
        fakePickerApi.nextPickedImage = NativePickedMedia(
          path: '/tmp/huge.jpg',
          type: NativeMediaType.image,
          sizeBytes: 10 * 1024 * 1024,
        );

        expect(
          () => MediaPicker.pickImage(
            source: MediaSource.gallery,
            options: const MediaSelectionOptions(maxSizeBytes: 1024 * 1024),
          ),
          throwsA(
            isA<MediaForgeException>().having(
              (e) => e.code,
              'code',
              MediaForgeErrorCode.validationFailed,
            ),
          ),
        );
      },
    );

    test('pickVideo returns PickedMedia with duration', () async {
      fakePickerApi.nextPickedVideo = NativePickedMedia(
        path: '/tmp/movie.mp4',
        type: NativeMediaType.video,
        name: 'movie.mp4',
        mimeType: 'video/mp4',
        sizeBytes: 10240,
        durationMs: 15000,
      );

      final result = await MediaPicker.pickVideo(source: MediaSource.gallery);

      expect(result, isNotNull);
      expect(result!.path, '/tmp/movie.mp4');
      expect(result.type, MediaType.video);
      expect(result.duration, const Duration(seconds: 15));
      expect(result.isVideo, isTrue);
    });

    test('pickMultiple returns list and validates count', () async {
      fakePickerApi.nextPickedMultiple = [
        NativePickedMedia(
          path: '/tmp/1.jpg',
          type: NativeMediaType.image,
          sizeBytes: 500,
        ),
        NativePickedMedia(
          path: '/tmp/2.jpg',
          type: NativeMediaType.image,
          sizeBytes: 600,
        ),
      ];

      final results = await MediaPicker.pickMultiple(
        type: MediaType.image,
        maxItems: 5,
      );
      expect(results.length, 2);
      expect(results[0].path, '/tmp/1.jpg');
      expect(results[1].path, '/tmp/2.jpg');
    });

    test('pickMultiple throws when count exceeds maxItems', () async {
      fakePickerApi.nextPickedMultiple = [
        NativePickedMedia(path: '/tmp/1.jpg', type: NativeMediaType.image),
        NativePickedMedia(path: '/tmp/2.jpg', type: NativeMediaType.image),
        NativePickedMedia(path: '/tmp/3.jpg', type: NativeMediaType.image),
      ];

      expect(
        () => MediaPicker.pickMultiple(type: MediaType.image, maxItems: 2),
        throwsA(
          isA<MediaForgeException>().having(
            (e) => e.code,
            'code',
            MediaForgeErrorCode.validationFailed,
          ),
        ),
      );
    });

    test('retrieveLostData returns recovered items', () async {
      fakePickerApi.nextLostData = NativeLostDataResponse(
        items: [
          NativePickedMedia(
            path: '/tmp/recovered.jpg',
            type: NativeMediaType.image,
          ),
        ],
      );

      final response = await MediaPicker.retrieveLostData();
      expect(response.isNotEmpty, isTrue);
      expect(response.items.length, 1);
      expect(response.items.first.path, '/tmp/recovered.jpg');
      expect(response.exception, isNull);
    });

    test(
      'maps native permission error to MediaForgeException.permissionDenied',
      () async {
        fakePickerApi.errorToThrow = PlatformException(
          code: 'permission_denied',
          message: 'Camera permission was denied',
        );

        expect(
          () => MediaPicker.pickImage(source: MediaSource.camera),
          throwsA(
            isA<MediaForgeException>().having(
              (e) => e.code,
              'code',
              MediaForgeErrorCode.permissionDenied,
            ),
          ),
        );
      },
    );

    test('facade MediaForge delegates correctly', () async {
      fakePickerApi.nextPickedImage = NativePickedMedia(
        path: '/tmp/facade.jpg',
        type: NativeMediaType.image,
      );

      final result = await MediaForge.pickImage();
      expect(result, isNotNull);
      expect(result!.path, '/tmp/facade.jpg');
    });
  });
}

class FakeMediaForgePickerApi implements MediaForgePickerApi {
  NativePickedMedia? nextPickedImage;
  NativePickedMedia? nextPickedVideo;
  List<NativePickedMedia> nextPickedMultiple = [];
  NativeLostDataResponse nextLostData = NativeLostDataResponse(items: []);
  Object? errorToThrow;

  @override
  Future<NativePickedMedia?> pickImage(
    NativeMediaSource source,
    NativePickerOptions? options,
  ) async {
    if (errorToThrow != null) throw errorToThrow!;
    return nextPickedImage;
  }

  @override
  Future<NativePickedMedia?> pickVideo(
    NativeMediaSource source,
    NativePickerOptions? options,
  ) async {
    if (errorToThrow != null) throw errorToThrow!;
    return nextPickedVideo;
  }

  @override
  Future<List<NativePickedMedia>> pickMultiple(
    NativeMediaType type,
    NativePickerOptions? options,
  ) async {
    if (errorToThrow != null) throw errorToThrow!;
    return nextPickedMultiple;
  }

  @override
  Future<NativeLostDataResponse> retrieveLostData() async {
    if (errorToThrow != null) throw errorToThrow!;
    return nextLostData;
  }

  @override
  // ignore: non_constant_identifier_names
  BinaryMessenger? get pigeonVar_binaryMessenger => null;

  @override
  // ignore: non_constant_identifier_names
  String get pigeonVar_messageChannelSuffix => '';
}
