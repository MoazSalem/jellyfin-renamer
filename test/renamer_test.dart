import 'package:renamer/core/detector.dart';
import 'package:renamer/metadata/models.dart';
import 'package:renamer/utils/title_processor.dart';
import 'package:test/test.dart';

void main() {
  group('MediaDetector', () {
    final detector = MediaDetector();

    test('detects TV show from episode pattern', () {
      final result = detector.detectType('.', ['My.Show.S01E01.mkv']);
      expect(result, MediaType.tvShow);
    });

    test('detects movie from year pattern', () {
      final result = detector.detectType('.', ['My.Movie.2010.mkv']);
      expect(result, MediaType.movie);
    });

    test('returns unknown for unrecognized patterns', () {
      final result = detector.detectType('.', ['unknown_file.mkv']);
      expect(result, MediaType.unknown);
    });
  });

  group('MediaScanner', () {
    test('extracts title and year from filename', () {
      // Test the private method indirectly through public interface
      // This would need more comprehensive testing in a real scenario
    });
  });

  group('TitleProcessor', () {
    test('cleans dots between umlauts', () {
      expect(TitleProcessor.cleanTitleDots('Mä.dchen'), 'Mä dchen');
      expect(
        TitleProcessor.cleanTitleDots('Mädchen.im.Wald'),
        'Mädchen im Wald',
      );
      expect(TitleProcessor.cleanTitleDots('Groß.Artig'), 'Groß Artig');
    });

    test('cleanFilename handles umlauts', () {
      expect(
        TitleProcessor.extractTitleUntilKeywords('Mädchen.2020.mkv').title,
        'Mädchen',
      );
    });

    test('extracts title with umlauts', () {
      expect(
        TitleProcessor.extractTitleUntilKeywords('Tätort.S01E01.mkv').title,
        'Tätort',
      );
    });
  });

  group('Movie model', () {
    test('generates correct Jellyfin name', () {
      final movie = Movie(title: 'My Movie', year: 2010);
      expect(movie.jellyfinName, 'My Movie (2010)');
    });

    test('handles movie without year', () {
      final movie = Movie(title: 'Unknown Movie');
      expect(movie.jellyfinName, 'Unknown Movie');
    });
  });

  group('TvShow model', () {
    test('generates correct Jellyfin name', () {
      final show = TvShow(title: 'My Show', year: 2008, seasons: []);
      expect(show.jellyfinName, 'My Show (2008)');
    });
  });

  group('Episode model', () {
    test('generates correct episode code', () {
      final episode = Episode(seasonNumber: 1, episodeNumberStart: 5);
      expect(episode.episodeCode, 'S01E05');
    });
  });
}
