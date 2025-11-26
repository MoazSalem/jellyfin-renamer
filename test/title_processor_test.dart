import 'package:renamer/utils/title_processor.dart';
import 'package:test/test.dart';

void main() {
  group('TitleProcessor', () {
    test('should extract year from parentheses before cleaning', () {
      final result = TitleProcessor.extractTitleUntilKeywords(
        'My Movie (2022).mkv',
      );
      expect(result.title, 'My Movie');
      expect(result.year, 2022);
    });

    test('should remove trailing hyphens from title', () {
      final result = TitleProcessor.extractTitleUntilKeywords(
        'My Show - S02E01 - Episode Title.mkv',
      );
      expect(result.title, 'My Show');
    });

    test('should handle standard title extraction', () {
      final result = TitleProcessor.extractTitleUntilKeywords(
        'My Show S01E01.mkv',
      );
      expect(result.title, 'My Show');
    });

    test('should handle title with year', () {
      final result = TitleProcessor.extractTitleUntilKeywords(
        'My Movie 2023.mkv',
      );
      expect(result.title, 'My Movie');
      expect(result.year, 2023);
    });
  });
}
