import 'package:renamer/core/detector.dart';
import 'package:renamer/metadata/models.dart';
import 'package:test/test.dart';

void main() {
  group('MediaDetector', () {
    final detector = MediaDetector();

    test('detects TV show from episode pattern', () {
      final result = detector.detectType('.', ['Breaking.Bad.S01E01.mkv']);
      expect(result, MediaType.tvShow);
    });

    test('detects movie from year pattern', () {
      final result = detector.detectType('.', ['Inception.2010.mkv']);
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

  group('Movie model', () {
    test('generates correct Jellyfin name', () {
      final movie = Movie(title: 'Inception', year: 2010);
      expect(movie.jellyfinName, 'Inception (2010)');
    });

    test('handles movie without year', () {
      final movie = Movie(title: 'Unknown Movie');
      expect(movie.jellyfinName, 'Unknown Movie');
    });
  });

  group('TvShow model', () {
    test('generates correct Jellyfin name', () {
      final show = TvShow(title: 'Breaking Bad', year: 2008, seasons: []);
      expect(show.jellyfinName, 'Breaking Bad (2008)');
    });
  });

  group('Episode model', () {
    test('generates correct episode code', () {
      final episode = Episode(seasonNumber: 1, episodeNumberStart: 5);
      expect(episode.episodeCode, 'S01E05');
    });
  });
}
