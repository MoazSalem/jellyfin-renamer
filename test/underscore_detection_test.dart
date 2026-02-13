import 'package:renamer/core/detector.dart';
import 'package:renamer/metadata/models.dart';
import 'package:renamer/utils/title_processor.dart';
import 'package:test/test.dart';

void main() {
  group('Underscore Title Detection', () {
    test('Detects movie with underscores in title and around year', () {
      final detector = MediaDetector();
      const filename =
          'Some_Random_Name_2025_1080p_10bit_BluRay_8CH_x265_HEVC.mkv';

      final type = detector.detectType('.', [filename]);

      expect(
        type,
        equals(MediaType.movie),
        reason: 'Should detect as movie based on year',
      );
    });

    test('Extracts title and year correctly from underscore filename', () {
      const filename =
          'Some_Random_Name_2025_1080p_10bit_BluRay_8CH_x265_HEVC.mkv';

      final result = TitleProcessor.extractTitleUntilKeywords(filename);

      expect(result.year, equals(2025), reason: 'Should extract year 2025');
      expect(
        result.title,
        equals('Some Random Name'),
        reason: 'Should extract clean title',
      );
    });
  });
}
