import 'package:renamer/metadata/models.dart';

/// Utility class for detecting media types from file patterns.
class MediaDetector {
  /// Detects the media type based on file patterns in the given
  /// directory.
  ///
  /// Returns [MediaType.tvShow] if episode patterns are found,
  /// [MediaType.movie] if year patterns are found,
  /// otherwise [MediaType.unknown].
  MediaType detectType(String directoryPath, List<String> files) {
    // Check for episode patterns in filenames (SxxExx) this indicates TV shows
    final hasEpisodes = files.any(
      (file) =>
          RegExp(r'S\d{1,2}E\d{1,2}', caseSensitive: false).hasMatch(file),
    );

    if (hasEpisodes) {
      return MediaType.tvShow;
    }

    // Check for season folders (S01, Season 1, etc.)
    final hasSeasons = files.any(
      (file) =>
          RegExp(r'^S\d{2}$|^Season \d+', caseSensitive: false).hasMatch(file),
    );

    if (hasSeasons) {
      return MediaType.tvShow;
    }

    // Check filename for year pattern (like Movie.2010.mkv) -
    // indicates movies
    final hasYearInFilename = files.any(
      (file) => RegExp(r'\b(19|20)\d{2}\b').hasMatch(file),
    );

    if (hasYearInFilename) {
      return MediaType.movie;
    }

    // Check if this is a subdirectory with video files
    // (typical movie structure)
    final videoFiles = files.where((f) {
      final ext = f.toLowerCase();
      return ext.endsWith('.mkv') ||
          ext.endsWith('.mp4') ||
          ext.endsWith('.avi') ||
          ext.endsWith('.mov') ||
          ext.endsWith('.m4v') ||
          ext.endsWith('.wmv');
    }).toList();

    // If we're in a subdirectory with video files, likely movies
    if (directoryPath.isNotEmpty &&
        directoryPath != '.' &&
        videoFiles.isNotEmpty) {
      return MediaType.movie;
    }

    // Check directory name for year pattern (common in movie folders)
    if (RegExp(r'\(\d{4}\)').hasMatch(directoryPath)) {
      return MediaType.movie;
    }

    return MediaType.unknown;
  }
}
