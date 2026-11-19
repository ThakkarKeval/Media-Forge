import 'package:flutter_test/flutter_test.dart';
import 'package:media_forge/media_forge.dart';

void main() {
  const validator = PickerValidator();

  group('PickerValidator', () {
    test('passes valid media with no constraints', () async {
      const media = PickedMedia(
        path: '/tmp/test.jpg',
        type: MediaType.image,
        sizeBytes: 1024,
        width: 800,
        height: 600,
      );

      final result = await validator.validate(
        media,
        const MediaSelectionOptions(),
      );
      expect(result.isValid, isTrue);
      expect(result.violations, isEmpty);
    });

    test('validates maxSizeBytes constraint', () async {
      const media = PickedMedia(
        path: '/tmp/large.jpg',
        type: MediaType.image,
        sizeBytes: 5 * 1024 * 1024, // 5MB
      );

      final validResult = await validator.validate(
        media,
        const MediaSelectionOptions(maxSizeBytes: 10 * 1024 * 1024),
      );
      expect(validResult.isValid, isTrue);

      final invalidResult = await validator.validate(
        media,
        const MediaSelectionOptions(maxSizeBytes: 2 * 1024 * 1024),
      );
      expect(invalidResult.isValid, isFalse);
      expect(
        invalidResult.violations.first,
        contains('exceeds maximum allowed size'),
      );
    });

    test('validates maxWidth and maxHeight dimensions', () async {
      const media = PickedMedia(
        path: '/tmp/photo.jpg',
        type: MediaType.image,
        width: 3840,
        height: 2160,
      );

      final validResult = await validator.validate(
        media,
        const MediaSelectionOptions(maxWidth: 4000, maxHeight: 4000),
      );
      expect(validResult.isValid, isTrue);

      final invalidResult = await validator.validate(
        media,
        const MediaSelectionOptions(maxWidth: 1920, maxHeight: 1080),
      );
      expect(invalidResult.isValid, isFalse);
      expect(invalidResult.violations.length, 2);
      expect(invalidResult.violations[0], contains('Width (3840px) exceeds'));
      expect(invalidResult.violations[1], contains('Height (2160px) exceeds'));
    });

    test('validates video duration constraint', () async {
      const video = PickedMedia(
        path: '/tmp/clip.mp4',
        type: MediaType.video,
        duration: Duration(seconds: 45),
      );

      final validResult = await validator.validate(
        video,
        const MediaSelectionOptions(maxDuration: Duration(minutes: 1)),
      );
      expect(validResult.isValid, isTrue);

      final invalidResult = await validator.validate(
        video,
        const MediaSelectionOptions(maxDuration: Duration(seconds: 30)),
      );
      expect(invalidResult.isValid, isFalse);
      expect(
        invalidResult.violations.first,
        contains('Duration (45s) exceeds'),
      );
    });

    test('validates allowed MIME types (exact and wildcard)', () async {
      const jpeg = PickedMedia(
        path: '/tmp/image.jpg',
        type: MediaType.image,
        mimeType: 'image/jpeg',
      );
      const png = PickedMedia(
        path: '/tmp/image.png',
        type: MediaType.image,
        mimeType: 'image/png',
      );

      final exactOptions = const MediaSelectionOptions(
        allowedMimeTypes: ['image/jpeg'],
      );
      expect((await validator.validate(jpeg, exactOptions)).isValid, isTrue);
      expect((await validator.validate(png, exactOptions)).isValid, isFalse);

      final wildcardOptions = const MediaSelectionOptions(
        allowedMimeTypes: ['image/*'],
      );
      expect((await validator.validate(jpeg, wildcardOptions)).isValid, isTrue);
      expect((await validator.validate(png, wildcardOptions)).isValid, isTrue);
    });

    test(
      'validateAll enforces maxItems and reports per-item violations',
      () async {
        final items = [
          const PickedMedia(
            path: '/tmp/1.jpg',
            type: MediaType.image,
            sizeBytes: 100,
          ),
          const PickedMedia(
            path: '/tmp/2.jpg',
            type: MediaType.image,
            sizeBytes: 5000,
          ),
          const PickedMedia(
            path: '/tmp/3.jpg',
            type: MediaType.image,
            sizeBytes: 200,
          ),
        ];

        final countResult = await validator.validateAll(
          items,
          const MediaSelectionOptions(maxItems: 2),
        );
        expect(countResult.isValid, isFalse);
        expect(
          countResult.violations.first,
          contains('Selected 3 items, but maximum'),
        );

        final sizeResult = await validator.validateAll(
          items,
          const MediaSelectionOptions(maxSizeBytes: 1000),
        );
        expect(sizeResult.isValid, isFalse);
        expect(
          sizeResult.violations.any((v) => v.contains('Item [2]')),
          isTrue,
        );
      },
    );
  });
}
