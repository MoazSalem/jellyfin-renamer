import 'package:renamer/utils/sort_utils.dart';
import 'package:test/test.dart';

void main() {
  group('SortUtils', () {
    test('should sort numbers naturally', () {
      final list = ['File 10', 'File 2', 'File 1']
        ..sort(SortUtils.naturalCompare);
      expect(list, ['File 1', 'File 2', 'File 10']);
    });

    test('should sort complex filenames naturally', () {
      final list = [
        'Show S01E10.mp4',
        'Show S01E02.mp4',
        'Show S01E100.mp4',
        'Show S01E01.mp4',
      ]..sort(SortUtils.naturalCompare);
      expect(list, [
        'Show S01E01.mp4',
        'Show S01E02.mp4',
        'Show S01E10.mp4',
        'Show S01E100.mp4',
      ]);
    });

    test('should handle mixed text and numbers', () {
      final list = ['a1b', 'a10b', 'a2b']..sort(SortUtils.naturalCompare);
      expect(list, ['a1b', 'a2b', 'a10b']);
    });

    test('should handle fractional numbers as separate parts', () {
      // Note: The current implementation splits
      // by non-digits, so 1.5 is [1, ., 5]
      // This means 1.5 vs 1.10 -> 1=1, .=., 5 vs 10 -> 5 < 10. Correct.
      final list = ['v1.10', 'v1.2', 'v1.1']..sort(SortUtils.naturalCompare);
      expect(list, ['v1.1', 'v1.2', 'v1.10']);
    });

    test('should handle standard string comparison when no numbers', () {
      final list = ['b', 'a', 'c']..sort(SortUtils.naturalCompare);
      expect(list, ['a', 'b', 'c']);
    });
  });
}
