import 'package:renamer/core/scanner.dart';
import 'package:test/test.dart';

void main() {
  group('MediaScanner', () {
    // This is a bit of a hack to test a private method.
    // In a real-world scenario, we might make _extractEpisodeInfo a public
    // static method on a utility class, or test it via the public
    // scanDirectory method. For this exercise, we'll expose it for testing.
    final scanner = MediaScanner();

    test('detects episode with attached number in Season folder', () {
      // Pattern: MyShow1.mp4 in Season 1 folder
      final result = scanner.extractEpisodeInfo(
        'path/to/My Show/Season 1/MyShow1.mp4',
      );
      expect(result, isNotNull);
      expect(result!.seasonNumber, 1);
      expect(result.episodeNumberStart, 1);
      expect(result.episodeNumberEnd, isNull);
    });

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

    test('should parse "episode 0" format', () {
      final result = scanner.extractEpisodeInfo('My Show - episode 0.mkv');
      expect(result, isNotNull);
      expect(result!.seasonNumber, 1);
      expect(result.episodeNumberStart, 0);
      expect(result.episodeNumberEnd, isNull);
    });

    test('should parse "season one" format', () {
      final result = scanner.extractEpisodeInfo('season one/01.mkv');
      expect(result, isNotNull);
      expect(result!.seasonNumber, 1);
      expect(result.episodeNumberStart, 1);
      expect(result.episodeNumberEnd, isNull);
    });

    test('should parse "first season" format', () {
      final result = scanner.extractEpisodeInfo('first season/01.mkv');
      expect(result, isNotNull);
      expect(result!.seasonNumber, 1);
      expect(result.episodeNumberStart, 1);
      expect(result.episodeNumberEnd, isNull);
    });

    test('should parse "الحلقة 1" format', () {
      final result = scanner.extractEpisodeInfo('My Show - الحلقة 1.mkv');
      expect(result, isNotNull);
      expect(result!.seasonNumber, 1);
      expect(result.episodeNumberStart, 1);
      expect(result.episodeNumberEnd, isNull);
    });

    test('should parse "EP 05" format correctly', () {
      final result = scanner.extractEpisodeInfo(
        'My Show/MS EP 05 FHD.mp4',
      );
      expect(result, isNotNull);
      expect(result!.seasonNumber, 1);
      expect(result.episodeNumberStart, 5);
      expect(result.episodeNumberEnd, isNull);
    });

    test('should not match numbers from show name', () {
      final result = scanner.extractEpisodeInfo(
        'Show100/Show100 EP 03.mp4',
      );
      expect(result, isNotNull);
      expect(result!.seasonNumber, 1);
      expect(result.episodeNumberStart, 3);
      expect(result.episodeNumberEnd, isNull);
    });

    test('should parse "Title-Episode" pattern when matching parent directory', () {
      final result = scanner.extractEpisodeInfo(
        'My Show/My Show-01.mp4',
      );
      expect(result, isNotNull);
      expect(result!.seasonNumber, 1);
      expect(result.episodeNumberStart, 1);
      expect(result.episodeNumberEnd, isNull);
    });

    test('should parse "bracketed episode numbers" format', () {
      final result = scanner.extractEpisodeInfo(
        'My Show [01].mkv',
      );
      expect(result, isNotNull);
      expect(result!.seasonNumber, 1); // Default to season 1
      expect(result.episodeNumberStart, 1);
      expect(result.episodeNumberEnd, isNull);
    });

    test('should fuzzy match "My Show" with space difference', () {
      // MyShow vs My Show
      // Also tests suffix handling [Web-DL...]
      final result = scanner.extractEpisodeInfo(
        'My Show/[ReleaseGroup] MyShow - 01 [Web-DL - 1080p - X265].mkv',
      );
      expect(result, isNotNull);
      expect(result!.seasonNumber, 1);
      expect(result.episodeNumberStart, 1);
    });

    test('should handle underscores and suffixes in "My Show"', () {
      final result = scanner.extractEpisodeInfo(
        'My Show/[RG]My_Show_-_01_(Dual Audio_10bit_1080p_x265).mkv',
      );
      expect(result, isNotNull);
      expect(result!.seasonNumber, 1);
      expect(result.episodeNumberStart, 1);
    });

    test('should fuzzy match "My Long Show" with acronym/shortening', () {
      // My L Show vs My Long Show
      final result = scanner.extractEpisodeInfo(
        'My Long Show/[ReleaseGroup] My L Show - 01 [Web-DL - 1080p - X265].mkv',
      );
      expect(result, isNotNull);
      expect(result!.seasonNumber, 1);
      expect(result.episodeNumberStart, 1);
    });

    test('should fuzzy match "My Very Long Show" with acronym', () {
      // M-VL'sS vs My Very Long Show
      final result = scanner.extractEpisodeInfo(
        'My Very Long Show/[ReleaseGroup] M-VL\'sS  - 01 [Web-DL - 1080p - X265].mkv',
      );
      expect(result, isNotNull);
      expect(result!.seasonNumber, 1);
      expect(result.episodeNumberStart, 1);
    });

    test('detects My Show S2 with acronym', () {
      // F:\Anime\My Show S2\[Anime-Sanka.com][AnimeSanka.xyz] MS S2 - 01 [Web-DL - 1080p - X265].mkv
      final result = scanner.extractEpisodeInfo(
        'My Show S2/[Anime-Sanka.com][AnimeSanka.xyz] MS S2 - 01 [Web-DL - 1080p - X265].mkv',
      );
      expect(result, isNotNull, reason: 'Should detect MS S2 as episode');
      expect(result!.seasonNumber, 2);
      expect(result.episodeNumberStart, 1);
    });

    test('detects My Japanese Show with Japanese acronym', () {
      // F:\Anime\my japanese show\[Anime-Sanka.com][AnimeSanka.xyz] WaShKe - 01 [Web-DL - 1080p - X265].mkv
      final result = scanner.extractEpisodeInfo(
        'my japanese show/[Anime-Sanka.com][AnimeSanka.xyz] WaShKe - 01 [Web-DL - 1080p - X265].mkv',
      );
      expect(result, isNotNull, reason: 'Should detect WaShKe as episode');
      expect(result!.episodeNumberStart, 1);
    });

    test('detects My Other Show S2 with short acronym', () {
      // F:\Anime\My Other Show Season 2\[AnimeSanka.com] O S2 - 01 [Bluray - 1080p - Ar - X265].mkv
      final result = scanner.extractEpisodeInfo(
        'My Other Show Season 2/[AnimeSanka.com] O S2 - 01 [Bluray - 1080p - Ar - X265].mkv',
      );
      expect(result, isNotNull, reason: 'Should detect O S2 as episode');
      expect(result!.seasonNumber, 2);
      expect(result.episodeNumberStart, 1);
    });

    test('detects Another Show with acronym', () {
      // F:\Anime\Another Show\[AnimeSanka.com] YS - 01  [Bluray - 1080p - Ar - X265].mkv
      final result = scanner.extractEpisodeInfo(
        'Another Show/[AnimeSanka.com] YS - 01  [Bluray - 1080p - Ar - X265].mkv',
      );
      expect(result, isNotNull, reason: 'Should detect YS as episode');
      expect(result!.episodeNumberStart, 1);
    });

    test('detects Spaced Show with spaced acronym', () {
      // F:\Anime\Spaced Show\[AnimeSanka.com] S E - 01 [BLURAY - 720P - AR - X265].mkv
      final result = scanner.extractEpisodeInfo(
        'Spaced Show/[AnimeSanka.com] S E - 01 [BLURAY - 720P - AR - X265].mkv',
      );
      expect(result, isNotNull, reason: 'Should detect S E as episode');
      expect(result!.episodeNumberStart, 1);
    });

    test('detects Simple Show with simple numbering', () {
      // F:\Anime\Simple Show\001.mp4
      // Note: extractEpisodeInfo expects full path for context
      final result = scanner.extractEpisodeInfo(
        'Simple Show/001.mp4',
      );
      expect(result, isNotNull, reason: 'Should detect 001 as episode');
      expect(result!.episodeNumberStart, 1);
    });
  });
}
