import 'package:renamer/core/grouper.dart';
import 'package:renamer/metadata/models.dart';
import 'package:test/test.dart';

void main() {
  group('TvShowGrouper', () {
    final grouper = TvShowGrouper();

    test('groups shows with word-based season names correctly', () {
      final items = [
        MediaItem(
          path: 'My Show/Season One/S01E01.mkv',
          type: MediaType.tvShow,
          episode: Episode(seasonNumber: 1, episodeNumberStart: 1),
        ),
        MediaItem(
          path: 'My Show/Second Season/S02E01.mkv',
          type: MediaType.tvShow,
          episode: Episode(seasonNumber: 2, episodeNumberStart: 1),
        ),
      ];

      final grouped = grouper.groupShows(items);

      expect(grouped.length, 1);
      expect(grouped.keys.first, 'my show');
      expect(grouped.values.first.length, 2);
    });
  });
}
