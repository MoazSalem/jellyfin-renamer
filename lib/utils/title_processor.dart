import 'package:renamer/config/file_extensions.dart';

/// Utility class for title extraction and cleaning operations.
class TitleProcessor {
  /// Checks if a detected title looks reasonable for media naming.
  ///
  /// Returns false if the title seems too short, contains file extensions,
  /// or has other indicators of poor extraction.
  static bool isTitleReasonable(String? title) {
    if (title == null || title.isEmpty) return false;
    if (title.length < 2) return false;

    // Check for file extensions that shouldn't be in titles
    final extensions = [...FileExtensions.video, ...FileExtensions.subtitle];
    if (extensions.any((ext) => title.toLowerCase().contains(ext))) {
      return false;
    }

    // Check for episode codes that might indicate poor extraction
    if (RegExp(r'S\d{1,2}E\d{1,2}', caseSensitive: false).hasMatch(title)) {
      return false;
    }

    return true;
  }

  /// Extracts title from filename using keyword-based stopping patterns.
  ///
  /// Stops at the earliest occurrence of Season/SNN/year patterns or words from `filenameFilterWords`.
  static ({String? title, int? year}) extractTitleUntilKeywords(
    String fileName,
  ) {
    // Clean the filename first
    // First, extract the year from the raw filename.
    // We do this before cleaning because cleaning might remove parentheses containing the year.
    final yearMatch = RegExp(r'\b(19|20)\d{2}\b').firstMatch(fileName);
    final year = yearMatch != null ? int.tryParse(yearMatch.group(0)!) : null;

    // Clean the filename
    final cleanName = _cleanFilename(fileName);

    // Now, find the earliest keyword to determine where the title ends.
    final patterns = [
      r'\bSeason\b',
      r'S\d{1,2}E\d{1,2}',
      r'\bS\d{1,2}\b',
      r'\b(19|20)\d{2}\b', // Keep year here to find title boundary
      ...filenameFilterWords.map((word) => r'\b' + RegExp.escape(word) + r'\b'),
      ...FileExtensions.video.map((ext) => r'\b' + RegExp.escape(ext.replaceAll('.', '')) + r'\b'),
      ...FileExtensions.subtitle.map((ext) => r'\b' + RegExp.escape(ext.replaceAll('.', '')) + r'\b'),
    ];

    var earliestEndIndex = cleanName.length;

    for (final pattern in patterns) {
      final match = RegExp(pattern, caseSensitive: false).firstMatch(cleanName);
      if (match != null && match.start < earliestEndIndex) {
        earliestEndIndex = match.start;
      }
    }

    // Extract the title part before the keyword
    var title = cleanName.substring(0, earliestEndIndex).trim();

    // Final cleanup of the extracted title
    title = title.replaceAll(RegExp(r'[\s._-]+$'), '').trim();

    return (title: title.isNotEmpty ? title : null, year: year);
  }

  /// Cleans up dots in titles intelligently.
  ///
  /// Replaces dots used as word separators with spaces and removes leading/trailing dots.
  static String cleanTitleDots(String title) {
    var result = title;

    // Replace all dots between word characters with spaces
    result = result.replaceAllMapped(
      RegExp(r'(\w)\.(\w)'),
      (match) => '${match.group(1)} ${match.group(2)}',
    );

    // Remove leading and trailing dots
    result = result.replaceAll(RegExp(r'^\.+|\.+$'), '');

    return result;
  }

  /// Cleans filename by removing common artifacts.
  static String _cleanFilename(String fileName) {
    var cleanName = fileName;

    // Remove common emojis and special characters
    cleanName = cleanName.replaceAll(
      RegExp('[⭐☆★☆✨🌟🔥💫🌈🎬🎭📺📽️🎪🎨🎨🎭🎪📽️📺🎬🌈💫🔥🌟✨☆★☆⭐]'),
      '',
    );

    // Remove brackets and parentheses content
    cleanName = cleanName.replaceAll(
      RegExp(r'[\[({].*?[\])}]'),
      '',
    );

    // Replace dots and underscores with spaces
    cleanName = cleanName.replaceAll(RegExp('[._]'), ' ');

    // Clean up multiple spaces and normalize
    cleanName = cleanName.replaceAll(RegExp(r'\s+'), ' ').trim();

    return cleanName;
  }
}
