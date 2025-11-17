import 'package:path/path.dart' as path;
import 'package:renamer/metadata/models.dart';
import 'package:renamer/utils/title_processor.dart';

/// A Class to group tv shows by name
class TvShowGrouper {
  /// Group shows by name to find different versions of the same show
  ///
  /// Returns a map of show names to a list of show items
  Map<String, List<({String originalShowName, List<MediaItem> items})>>
  groupShows(List<MediaItem> tvShowItems) {
    final groupedByDirectory = <String, List<MediaItem>>{};

    for (final item in tvShowItems) {
      final itemDir = path.dirname(item.path);
      groupedByDirectory.putIfAbsent(itemDir, () => []).add(item);
    }

    final groupedByShowName =
        <String, List<({String originalShowName, List<MediaItem> items})>>{};

    for (final entry in groupedByDirectory.entries) {
      final directoryPath = entry.key;
      final directoryItems = entry.value;

      final originalShowNameGuess = _guessShowNameFromPath(directoryPath);
      final normalizedShowNameGuess = originalShowNameGuess.toLowerCase();

      groupedByShowName.putIfAbsent(normalizedShowNameGuess, () => []).add((
        originalShowName: originalShowNameGuess,
        items: directoryItems,
      ));
    }

    return groupedByShowName;
  }

  String _guessShowNameFromPath(String directoryPath) {
    final dirName = path.basename(directoryPath);
    final isSeasonDir = RegExp(
      r'^(season\s*\d+|s\d+)$',
      caseSensitive: false,
    ).hasMatch(dirName);

    if (isSeasonDir) {
      final parentDir = path.dirname(directoryPath);
      final parentDirName = path.basename(parentDir);
      final titleInfo = TitleProcessor.extractTitleUntilKeywords(parentDirName);
      return titleInfo.title ?? parentDirName;
    } else {
      final titleInfo = TitleProcessor.extractTitleUntilKeywords(dirName);
      return titleInfo.title ?? dirName;
    }
  }
}
