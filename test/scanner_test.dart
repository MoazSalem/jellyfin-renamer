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
      // F:\Anime\My Show S2\MS S2 - 01 [Web-DL - 1080p - X265].mkv
      final result = scanner.extractEpisodeInfo(
        'My Show S2/MS S2 - 01 [Web-DL - 1080p - X265].mkv',
      );
      expect(result, isNotNull, reason: 'Should detect MS S2 as episode');
      expect(result!.seasonNumber, 2);
      expect(result.episodeNumberStart, 1);
    });

    test('detects My Japanese Show with Japanese acronym', () {
      // F:\Anime\my japanese show\MJS - 01 [Web-DL - 1080p - X265].mkv
      final result = scanner.extractEpisodeInfo(
        'my japanese show/MJS - 01 [Web-DL - 1080p - X265].mkv',
      );
      expect(result, isNotNull, reason: 'Should detect MJS as episode');
      expect(result!.episodeNumberStart, 1);
    });

    test('detects My Other Show with short acronym', () {
      // F:\Anime\My Other Show\MOS - 01 [Bluray - 1080p - Ar - X265].mkv
      final result = scanner.extractEpisodeInfo(
        'My Other Show/MOS - 01 [Bluray - 1080p - Ar - X265].mkv',
      );
      expect(result, isNotNull, reason: 'Should detect MOS as episode');
      expect(result!.seasonNumber, 1);
      expect(result.episodeNumberStart, 1);
    });

    test('detects Another Show with acronym', () {
      // F:\Anime\Another Show Extra\ASE - 01  [Bluray - 1080p - Ar - X265].mkv
      final result = scanner.extractEpisodeInfo(
        'Another Show Extra/ASE - 01  [Bluray - 1080p - Ar - X265].mkv',
      );
      expect(result, isNotNull, reason: 'Should detect ASE as episode');
      expect(result!.episodeNumberStart, 1);
    });

    test('detects Spaced Show with spaced acronym', () {
      // F:\Anime\Spaced Show Extra\S S E - 01 [BLURAY - 720P - AR - X265].mkv
      final result = scanner.extractEpisodeInfo(
        'Spaced Show Extra/S S E - 01 [BLURAY - 720P - AR - X265].mkv',
      );
      expect(result, isNotNull, reason: 'Should detect S S E as episode');
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
    test('should correctly detect episode 12 and NOT S02E64 from x.264', () {
      final result = scanner.extractEpisodeInfo(
        'My Show/[ReleaseGroup] YS - 12 END (BD 1920x1080 x.264 DTS.mkv',
      );
      expect(result, isNotNull);
      expect(result!.seasonNumber, 1);
      expect(result.episodeNumberStart, 12);
    });
    test('should detect episode when number is attached to show name', () {
      final result = scanner.extractEpisodeInfo(
        'My Show/MyShow10.mp4',
      );
      expect(result, isNotNull);
      expect(result!.seasonNumber, 1);
      expect(result.episodeNumberStart, 10);
    });

    test('should detect episode with END suffix', () {
      final result = scanner.extractEpisodeInfo(
        'My Show/MyShowEND12.mp4',
      );
      expect(result, isNotNull);
      expect(result!.seasonNumber, 1);
      expect(result.episodeNumberStart, 12);
    });
    test('should prioritize EP26 over 1080 inside brackets', () {
      // TDA EP26 END [BD - 1080p - X265].mkv
      final result = scanner.extractEpisodeInfo(
        'TDA/TDA EP26 END [BD - 1080p - X265].mkv',
      );
      expect(result, isNotNull);
      expect(result!.seasonNumber, 1);
      expect(result.episodeNumberStart, 26); // Should be 26, not 1080
    });
    test('should detect absolute numbering for long running shows (One Piece)', () {
      // One Piece/100.mp4 -> Season 1, Episode 100
      var result = scanner.extractEpisodeInfo('One Piece/100.mp4');
      expect(result, isNotNull, reason: '100.mp4 should be detected');
      expect(result!.seasonNumber, 1);
      expect(result.episodeNumberStart, 100);

      // One Piece/1000.mp4 -> Season 1, Episode 1000
      result = scanner.extractEpisodeInfo('One Piece/1000.mp4');
      expect(result, isNotNull, reason: '1000.mp4 should be detected');
      expect(result!.seasonNumber, 1);
      expect(result.episodeNumberStart, 1000);

      // One Piece/200.mp4
      result = scanner.extractEpisodeInfo('One Piece/200.mp4');
      expect(result, isNotNull);
      expect(result!.seasonNumber, 1);
      expect(result.episodeNumberStart, 200);
    });

    test('should detect fuzzy attached numbers (Naruto Shippuden)', () {
      // Naruto shippuden/NarutoShippuuden307.mp4
      // Note: "shippuden" vs "Shippuuden" (extra u)
      final result = scanner.extractEpisodeInfo(
        'Naruto shippuden/NarutoShippuuden307.mp4',
      );
      expect(result, isNotNull, reason: 'NarutoShippuuden307 should be detected');
      expect(result!.seasonNumber, 1);
      expect(result.episodeNumberStart, 307);
    });
    test('should detect YakusokunoNeverland10', () {
      // Yakusoku no Neverland/YakusokunoNeverland10.mp4
      final result = scanner.extractEpisodeInfo(
        'Yakusoku no Neverland/YakusokunoNeverland10.mp4',
      );
      expect(result, isNotNull, reason: 'YakusokunoNeverland10 should be detected');
      expect(result!.seasonNumber, 1);
      expect(result.episodeNumberStart, 10);
    });

    test('should detect YakusokunoNeverlandEND12', () {
      // Yakusoku no Neverland/YakusokunoNeverlandEND12.mp4
      final result = scanner.extractEpisodeInfo(
        'Yakusoku no Neverland/YakusokunoNeverlandEND12.mp4',
      );
      expect(result, isNotNull, reason: 'YakusokunoNeverlandEND12 should be detected');
      expect(result!.seasonNumber, 1);
      expect(result.episodeNumberStart, 12);
    });
  });
}
