import 'package:renamer/core/scanner.dart';
import 'package:test/test.dart';

void main() {
  group('MediaScanner Episode Parsing', () {
    // This is a bit of a hack to test a private method.
    // In a real-world scenario, we might make _extractEpisodeInfo a public
    // static method on a utility class, or test it via the public
    // scanDirectory method. For this exercise, we'll expose it for testing.
    final scanner = MediaScanner();

    test('should parse standard SxxExx format', () {
      final result = scanner.extractEpisodeInfo('My.Show.S02E05.mkv');
      expect(result, isNotNull);
      expect(result!.seasonNumber, 2);
      expect(result.episodeNumberStart, 5);
      expect(result.episodeNumberEnd, isNull);
    });

    test('should parse multi-episode SxxExx-Exx format', () {
      final result = scanner.extractEpisodeInfo('My.Show.S03E01-E02.mkv');
      expect(result, isNotNull);
      expect(result!.seasonNumber, 3);
      expect(result.episodeNumberStart, 1);
      expect(result.episodeNumberEnd, 2);
    });

    test('should parse multi-episode SxxExx-xx format', () {
      final result = scanner.extractEpisodeInfo('My.Show.S03E03-04.mkv');
      expect(result, isNotNull);
      expect(result!.seasonNumber, 3);
      expect(result.episodeNumberStart, 3);
      expect(result.episodeNumberEnd, 4);
    });

    test('should parse three-digit format', () {
      final result = scanner.extractEpisodeInfo('My.Show.205.mkv');
      expect(result, isNotNull);
      expect(result!.seasonNumber, 2);
      expect(result.episodeNumberStart, 5);
      expect(result.episodeNumberEnd, isNull);
    });

    test('should parse three-digit multi-episode format', () {
      final result = scanner.extractEpisodeInfo('My.Show.323-24.mkv');
      expect(result, isNotNull);
      expect(result!.seasonNumber, 3);
      expect(result.episodeNumberStart, 23);
      expect(result.episodeNumberEnd, 24);
    });

    test('should parse numbered episode in season folder', () {
      final result = scanner.extractEpisodeInfo('Season 04/08.mkv');
      expect(result, isNotNull);
      expect(result!.seasonNumber, 4);
      expect(result.episodeNumberStart, 8);
      expect(result.episodeNumberEnd, isNull);
    });

    test('should parse multi-episode in season folder', () {
      final result = scanner.extractEpisodeInfo('Season 5/09-10.mkv');
      expect(result, isNotNull);
      expect(result!.seasonNumber, 5);
      expect(result.episodeNumberStart, 9);
      expect(result.episodeNumberEnd, 10);
    });

    test('should return null for non-episode formats', () {
      final result = scanner.extractEpisodeInfo('A normal file.mkv');
      expect(result, isNull);
    });

    test('should not parse SxxExx from other numbers', () {
      final result = scanner.extractEpisodeInfo('My.Show.S02E01.1080p.mkv');
      expect(result, isNotNull);
      expect(result!.seasonNumber, 2);
      expect(result.episodeNumberStart, 1);
      expect(result.episodeNumberEnd, isNull);
    });

    test('should parse "episode 01" format', () {
      final result = scanner.extractEpisodeInfo('My Show - episode 01.mkv');
      expect(result, isNotNull);
      expect(result!.seasonNumber, 1);
      expect(result.episodeNumberStart, 1);
      expect(result.episodeNumberEnd, isNull);
    });

    test('should parse "episode 01" format in season folder', () {
      final result = scanner.extractEpisodeInfo(
        'Season 2/My Show - episode 01.mkv',
      );
      expect(result, isNotNull);
      expect(result!.seasonNumber, 2);
      expect(result.episodeNumberStart, 1);
      expect(result.episodeNumberEnd, isNull);
    });

    test('should parse "e3" format', () {
      final result = scanner.extractEpisodeInfo('My Show - e3.mkv');
      expect(result, isNotNull);
      expect(result!.seasonNumber, 1);
      expect(result.episodeNumberStart, 3);
      expect(result.episodeNumberEnd, isNull);
    });

    test('should parse "e03" format in season folder', () {
      final result = scanner.extractEpisodeInfo('Season 3/My Show - e03.mkv');
      expect(result, isNotNull);
      expect(result!.seasonNumber, 3);
      expect(result.episodeNumberStart, 3);
      expect(result.episodeNumberEnd, isNull);
    });
  });
}
