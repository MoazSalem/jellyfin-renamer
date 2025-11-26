import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:renamer/config/file_extensions.dart';
import 'package:renamer/metadata/models.dart';
import 'package:renamer/utils/logger.dart' as app_logger;
import 'package:renamer/utils/season_parser.dart';
import 'package:renamer/utils/title_processor.dart';

/// Scanner for discovering media files and their associated subtitle files.
class MediaScanner {
  /// Creates a new media scanner instance.
  ///
  /// [logger] logger instance, a default logger is used if not provided.
  MediaScanner({app_logger.AppLogger? logger})
    : _logger = logger ?? app_logger.AppLogger();

  final app_logger.AppLogger _logger;

  /// Scans the specified directory recursively for media files.
  ///
  /// Returns a list of [MediaItem] objects containing detected media files
  /// and their associated subtitle files.
  Future<ScanResult> scanDirectory(String rootPath) async {
    final videoFiles = <String>[];
    final subtitleFiles = <String>[];
    final rootDir = Directory(rootPath);

    if (!rootDir.existsSync()) {
      throw Exception('Directory does not exist: $rootPath');
    }

    // Collect all video and subtitle files
    await for (final entity in rootDir.list(recursive: true)) {
      if (entity is File) {
        final filePath = entity.path;
        if (_isVideoFile(filePath)) {
          videoFiles.add(filePath);
        } else if (_isSubtitleFile(filePath)) {
          subtitleFiles.add(filePath);
        }
      }
    }

    // Process video files and associate subtitles
    final items = <MediaItem>[];
    final associatedSubtitlePaths = <String>{};

    for (final videoPath in videoFiles) {
      final mediaItem = await _analyzeFile(videoPath, rootPath);
      if (mediaItem != null) {
        // Find associated subtitle files
        final associatedSubtitles = _findAssociatedSubtitles(
          videoPath,
          subtitleFiles,
        );
        associatedSubtitlePaths.addAll(associatedSubtitles);
        
        final mediaItemWithSubtitles = mediaItem.copyWith(
          subtitlePaths: associatedSubtitles,
        );
        items.add(mediaItemWithSubtitles);
      }
    }

    final unassociatedSubtitles = subtitleFiles
        .where((path) => !associatedSubtitlePaths.contains(path))
        .toList();

    return ScanResult(items: items, unassociatedSubtitles: unassociatedSubtitles);
  }

  bool _isVideoFile(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    return FileExtensions.video.contains(extension);
  }

  bool _isSubtitleFile(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    return FileExtensions.subtitle.contains(extension);
  }

  List<String> _findAssociatedSubtitles(
    String videoPath,
    List<String> subtitleFiles,
  ) {
    final videoDir = path.dirname(videoPath);
    final videoName = path.basenameWithoutExtension(videoPath);
    final associatedSubtitles = <String>[];

    for (final subtitlePath in subtitleFiles) {
      final subtitleDir = path.dirname(subtitlePath);
      final subtitleName = path.basenameWithoutExtension(subtitlePath);

      // Only consider subtitles in the same directory
      if (subtitleDir != videoDir) continue;

      // Check various matching patterns
      if (_isSubtitleForVideo(videoName, subtitleName)) {
        associatedSubtitles.add(subtitlePath);
      }
    }

    return associatedSubtitles;
  }

  bool _isSubtitleForVideo(String videoName, String subtitleName) {
    // Normalize both names for comparison
    final normalizedVideo = _normalizeForSubtitleMatching(videoName);
    final normalizedSubtitle = _normalizeForSubtitleMatching(subtitleName);

    // Exact match after normalization
    if (normalizedVideo == normalizedSubtitle) return true;

    // Episode code matching - check if both have the same episode code
    final videoEpisodeMatch = RegExp(
      r'S(\d{1,2})E(\d{1,2})',
      caseSensitive: false,
    ).firstMatch(videoName);
    final subtitleEpisodeMatch = RegExp(
      r'S(\d{1,2})E(\d{1,2})',
      caseSensitive: false,
    ).firstMatch(subtitleName);

    if (videoEpisodeMatch != null && subtitleEpisodeMatch != null) {
      final videoEpisode =
          'S${videoEpisodeMatch.group(1)}E${videoEpisodeMatch.group(2)}';
      final subtitleEpisode =
          'S${subtitleEpisodeMatch.group(1)}E${subtitleEpisodeMatch.group(2)}';
      if (videoEpisode == subtitleEpisode) return true;
      // If both have SxxExx but they are DIFFERENT, return false immediately.
      // This prevents falling through to "Common words matching" which might
      // match them based on the show name.
      return false;
    }

    // Check if they have the same episode code
    // even if one doesn't have it extracted
    if (videoEpisodeMatch != null || subtitleEpisodeMatch != null) {
      final episodeCode = videoEpisodeMatch != null
          ? 'S${videoEpisodeMatch.group(1)}E${videoEpisodeMatch.group(2)}'
          : 'S${subtitleEpisodeMatch!.group(1)}'
                'E${subtitleEpisodeMatch.group(2)}';
      if (videoName.contains(episodeCode) &&
          subtitleName.contains(episodeCode)) {
        return true;
      }
    }

    // Common words matching - check if they share significant words
    final videoWords = _extractSignificantWords(normalizedVideo);
    final subtitleWords = _extractSignificantWords(normalizedSubtitle);

    // If they share at least 2 significant words, consider them related
    final commonWords = videoWords.intersection(subtitleWords);
    if (commonWords.length >= 2) return true;

    // If we are dealing with simple numbered files, they must match exactly.
    final isVideoNumeric = RegExp(r'^\d+$').hasMatch(normalizedVideo);
    final isSubtitleNumeric = RegExp(r'^\d+$').hasMatch(normalizedSubtitle);
    if (isVideoNumeric && isSubtitleNumeric) {
      return false; // Exact match was already checked,
      // so these are different numbers.
    }

    // One name contains a significant portion of the other
    if (normalizedSubtitle.contains(normalizedVideo)) {
      // This is generally safe, e.g., subtitle has extra language tags
      return true;
    }

    if (normalizedVideo.contains(normalizedSubtitle)) {
      // This is less safe. Disallow if the subtitle is purely numeric,
      // as it's too ambiguous and leads to false positives
      // (e.g., '2' in 'S01E02').
      if (isSubtitleNumeric) {
        return false;
      }
      return true;
    }

    return false;
  }

  String _normalizeForSubtitleMatching(String name) {
    // Remove common quality indicators and extra info
    var normalized = name;
    for (final indicator in filenameFilterWords) {
      normalized = normalized.replaceAll(
        RegExp(r'\b' + RegExp.escape(indicator) + r'\b', caseSensitive: false),
        '',
      );
    }
    return normalized
        .replaceAll(RegExp(r'\([^)]*\)'), '') // Remove parentheses content
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Set<String> _extractSignificantWords(String text) {
    // Extract words that are likely to be meaningful for matching
    final words = text.split(RegExp(r'\s+'));
    return words.where((word) {
      // Keep words that are not just numbers,
      // single chars, or common quality terms
      return word.length > 2 &&
          !RegExp(r'^\d+$').hasMatch(word) &&
          !filenameFilterWords.contains(word.toLowerCase());
    }).toSet();
  }

  Future<MediaItem?> _analyzeFile(String filePath, String rootPath) async {
    try {
      final fileName = path.basenameWithoutExtension(filePath);

      // Detect media type based on filename and path
      final mediaType = _detectTypeFromFilename(filePath);

      // Extract basic title and year from filename
      final titleInfo = _extractTitleInfo(fileName);

      // Extract episode info if it's a TV show
      Episode? episode;
      if (mediaType == MediaType.tvShow) {
        episode = extractEpisodeInfo(filePath);
      }

      return MediaItem(
        path: filePath,
        type: mediaType,
        detectedTitle: titleInfo.title,
        detectedYear: titleInfo.year,
        episode: episode,
      );
    } on Exception catch (_) {
      // Skip files that can't be analyzed
      return null;
    }
  }

  /// Extracts episode information from the given file path.
  Episode? extractEpisodeInfo(String filePath) {
    _logger.debug('_extractEpisodeInfo called for filePath: $filePath');
    final fileName = path.basenameWithoutExtension(filePath);
    final parentDirName = path.basename(path.dirname(filePath));
    _logger.debug('fileName: $fileName, parentDirName: $parentDirName');

    // Pattern: Anime Release Group [Group] Title - 01 [Tags]
    // Check this FIRST as it is very specific and high confidence.
    // This avoids issues where other patterns (like 3-digit) match parts of the tags (e.g. x.264 -> 264).
    if (RegExp(r'^\[.+?\]\s*.+?\s*-\s*\d{1,4}').hasMatch(fileName)) {
      _logger.debug('Matched Anime Release Group pattern.');
      // Extract the episode number from the pattern
      final match = RegExp(r'-\s*(\d{1,4})').firstMatch(fileName);
      if (match != null) {
        final episodeNum = int.parse(match.group(1)!);
        final seasonNum = extractSeasonFromDirName(parentDirName) ?? 1;
        return Episode(seasonNumber: seasonNum, episodeNumberStart: episodeNum);
      }
    }

    // SxxExx Patterns (most specific first)
    // Pattern 1: S01E01-E02 or S01E01-02 (separator is mandatory)
    final multiEpMatch = RegExp(
      r'S(\d{1,2})E(\d{1,2})[-_]E?(\d{1,2})',
      caseSensitive: false,
    ).firstMatch(fileName);
    if (multiEpMatch != null) {
      _logger.debug('Matched multi-episode SxxExx-Exx pattern.');
      final seasonNum = int.parse(multiEpMatch.group(1)!);
      final startEp = int.parse(multiEpMatch.group(2)!);
      final endEp = int.parse(multiEpMatch.group(3)!);
      return Episode(
        seasonNumber: seasonNum,
        episodeNumberStart: startEp,
        episodeNumberEnd: endEp,
      );
    }

    // Pattern 2: S01E01 (single)
    final singleEpMatch = RegExp(
      r'S(\d{1,2})E(\d{1,2})',
      caseSensitive: false,
    ).firstMatch(fileName);
    if (singleEpMatch != null) {
      _logger.debug('Matched single SxxExx pattern.');
      final seasonNum = int.parse(singleEpMatch.group(1)!);
      final episodeNum = int.parse(singleEpMatch.group(2)!);
      return Episode(seasonNumber: seasonNum, episodeNumberStart: episodeNum);
    }

    // 3-Digit Patterns
    // Pattern 3: 323-324 or 323-24
    final threeDigitMultiMatch = RegExp(
      r'\b(\d{1,2})(\d{2})[-_](?:\d{1,2})?(\d{2})\b',
    ).firstMatch(fileName);
    if (threeDigitMultiMatch != null) {
      _logger.debug('Matched 3-digit multi-episode pattern.');
      final seasonNum = int.parse(threeDigitMultiMatch.group(1)!);
      final startEp = int.parse(threeDigitMultiMatch.group(2)!);
      final endEp = int.parse(threeDigitMultiMatch.group(3)!);
      if (seasonNum > 0 && startEp > 0 && endEp > 0) {
        return Episode(
          seasonNumber: seasonNum,
          episodeNumberStart: startEp,
          episodeNumberEnd: endEp,
        );
      }
    }

    // Pattern 4: EP/E pattern (check before 3-digit to avoid false matches)
    // Matches: EP 05, E05, e3, الحلقة 1, etc.
    final ePatternMatch = RegExp(
      r'(?:\bep?\s*|الحلقة\s*)(\d+)',
      caseSensitive: false,
    ).firstMatch(fileName);
    if (ePatternMatch != null) {
      _logger.debug('Matched EP/E pattern.');
      final episodeNum = int.parse(ePatternMatch.group(1)!);

      // Try to get season from parent folder
      final seasonNum = extractSeasonFromDirName(parentDirName);
      if (seasonNum != null) {
        return Episode(seasonNumber: seasonNum, episodeNumberStart: episodeNum);
      }

      // If no season in folder, assume season 1
      return Episode(seasonNumber: 1, episodeNumberStart: episodeNum);
    }

    // Pattern 5: 101 (single) - 3-digit episode code
    final threeDigitMatch = RegExp(
      r'\b(\d{1,2})(\d{2})\b',
    ).firstMatch(fileName);
    if (threeDigitMatch != null) {
      _logger.debug('Matched 3-digit single episode pattern.');
      final seasonNum = int.parse(threeDigitMatch.group(1)!);
      final episodeNum = int.parse(threeDigitMatch.group(2)!);
      
      // Allow season 0 (e.g. 001 -> S00E01 or just E01?)
      // Usually 001 is absolute numbering E01.
      // If seasonNum is 0, we can default to Season 1 for absolute numbering convenience?
      // Or keep it as Season 0 (Specials).
      // Let's assume Season 1 if seasonNum is 0, unless it's explicitly S00.
      // But here we parsed '0' from '001'.
      final effectiveSeason = seasonNum == 0 ? 1 : seasonNum;

      if (seasonNum >= 0 && seasonNum < 50 && episodeNum > 0) {
        return Episode(seasonNumber: effectiveSeason, episodeNumberStart: episodeNum);
      }
    }

    // Pattern: Bracketed number [01]
    final bracketedMatch = RegExp(r'\[(\d{1,3})\]').firstMatch(fileName);
    if (bracketedMatch != null) {
      _logger.debug('Matched bracketed number pattern.');
      final num = int.parse(bracketedMatch.group(1)!);
      // Avoid matching years (e.g. [2023])
      if (num < 1900) {
        final seasonNum = extractSeasonFromDirName(parentDirName) ?? 1;
        return Episode(seasonNumber: seasonNum, episodeNumberStart: num);
      }
    }

    // Season Folder Context Patterns
    final seasonNum = extractSeasonFromDirName(parentDirName);
    if (seasonNum != null) {
      _logger.debug(
        'Matched season in parent directory: $parentDirName',
      );

      // Pattern 6a: 12-13
      final folderMultiMatch = RegExp(
        r'^(\d{1,2})[-_](\d{1,2})$',
      ).firstMatch(fileName);
      if (folderMultiMatch != null) {
        _logger.debug('Matched multi-episode pattern in season folder.');
        final startEp = int.parse(folderMultiMatch.group(1)!);
        final endEp = int.parse(folderMultiMatch.group(2)!);
        return Episode(
          seasonNumber: seasonNum,
          episodeNumberStart: startEp,
          episodeNumberEnd: endEp,
        );
      }

      // Pattern 6b: 12 (single)
      final episodeFileMatch = RegExp(r'^(\d{1,3})$').firstMatch(fileName);
      if (episodeFileMatch != null) {
        _logger.debug('Matched single episode pattern in season folder.');
        final episodeNum = int.parse(episodeFileMatch.group(1)!);
        return Episode(seasonNumber: seasonNum, episodeNumberStart: episodeNum);
      }

      // Pattern 6c: Attached number (e.g. ShingekinoKyojin1)
      // Only if we are in a season folder, we can be more aggressive.
      // We look for a number at the very end of the string.
      final attachedNumberMatch = RegExp(r'(\d{1,3})$').firstMatch(fileName);
      if (attachedNumberMatch != null) {
         _logger.debug('Matched attached number pattern in season folder.');
         final episodeNum = int.parse(attachedNumberMatch.group(1)!);
         return Episode(seasonNumber: seasonNum, episodeNumberStart: episodeNum);
      }

      _logger.debug('No episode number match in filename for season folder.');
    }
    _logger.debug('No season match in parent directory.');

    // Pattern 7: Fallback for "episode XX" format
    final episodeWordMatch = RegExp(
      r'episode\s*(\d+)',
      caseSensitive: false,
    ).firstMatch(fileName);
    if (episodeWordMatch != null) {
      final episodeNum = int.parse(episodeWordMatch.group(1)!);
      final seasonNum = extractSeasonFromDirName(parentDirName);
      if (seasonNum != null) {
        return Episode(seasonNumber: seasonNum, episodeNumberStart: episodeNum);
      }
      // Assume season 1 if not otherwise specified
      return Episode(seasonNumber: 1, episodeNumberStart: episodeNum);
    }

    // Pattern 8: Title-Episode pattern (e.g., "Show Name - 01 [Extra]")
    final titleEpisodeMatch = RegExp(r'^(.+?)[-\s_]+(\d{1,3})(?:[-\s_\[\(].*)?$').firstMatch(fileName);
    if (titleEpisodeMatch != null) {
       final titlePart = titleEpisodeMatch.group(1)!.trim();
       final episodeNum = int.parse(titleEpisodeMatch.group(2)!);

       // Verify against parent directory to be safe
       if (_isFuzzyMatch(titlePart, parentDirName)) {
          final seasonNum = extractSeasonFromDirName(parentDirName);
          if (seasonNum != null) {
            return Episode(seasonNumber: seasonNum, episodeNumberStart: episodeNum);
          }
          // Assume season 1 if not otherwise specified
          return Episode(seasonNumber: 1, episodeNumberStart: episodeNum);
       }
    }

    return null;
  }

  MediaType _detectTypeFromFilename(String filePath) {
    final fileName = path.basenameWithoutExtension(filePath);
    final parentDirName = path.basename(path.dirname(filePath));

    // 1. SxxExx patterns (unambiguous TV)
    if (RegExp(r'S\d{1,2}E\d{1,2}', caseSensitive: false).hasMatch(fileName)) {
      return MediaType.tvShow;
    }

    if (RegExp(r'episode\s*\d+', caseSensitive: false).hasMatch(fileName)) {
      return MediaType.tvShow;
    }

    if (RegExp(
      r'(?:\bep?\s*|الحلقة\s*)(\d+)',
      caseSensitive: false,
    ).hasMatch(fileName)) {
      return MediaType.tvShow;
    }

    // Pattern: Bracketed number [01]
    final bracketedMatch = RegExp(r'\[(\d{1,3})\]').firstMatch(fileName);
    if (bracketedMatch != null) {
      final num = int.parse(bracketedMatch.group(1)!);
      if (num < 1900) {
        return MediaType.tvShow;
      }
    }

    // Pattern: Anime Release Group [Group] Title - 01 [Tags]
    if (RegExp(r'^\[.+?\]\s*.+?\s*-\s*\d{1,4}').hasMatch(fileName)) {
      return MediaType.tvShow;
    }

    // 2. Season folder context (unambiguous TV)
    if (extractSeasonFromDirName(parentDirName) != null) {
      // Check for numbered files inside
      if (RegExp(r'^\d{1,3}([-_]\d{1,3})?$').hasMatch(fileName)) {
        return MediaType.tvShow;
      }
      // Check for attached number at end (e.g. ShowName1)
      if (RegExp(r'\d{1,3}$').hasMatch(fileName)) {
        return MediaType.tvShow;
      }
    }

    // 3. Movie year pattern (unambiguous Movie)
    if (RegExp(r'\b(19|20)\d{2}\b').hasMatch(fileName)) {
      return MediaType.movie;
    }

    // 3b. Movie keyword
    if (RegExp(r'\bmovie\b', caseSensitive: false).hasMatch(fileName)) {
      return MediaType.movie;
    }

    // 4. 3-digit episode patterns (now less ambiguous)
    if (RegExp(r'\b\d{3,4}\b').hasMatch(fileName)) {
      final match = RegExp(r'\b(\d{1,2})(\d{2})\b').firstMatch(fileName);
      if (match != null) {
        final seasonNum = int.parse(match.group(1)!);
        // Allow season 0 (specials) or just treat 0 as season 1 if needed?
        // For 001, seasonNum is 0.
        if (seasonNum >= 0 && seasonNum < 50) {
          return MediaType.tvShow;
        }
      }
    }

    // 5. Title-Episode pattern (e.g., "Show Name - 01 [Extra]")
    // This is a heuristic: if the file ends in a number and the prefix
    // matches the parent directory name, it's likely an episode.
    // Allow underscores as separators too.
    final titleEpisodeMatch = RegExp(r'^(.+?)[-\s_]+(\d{1,3})(?:[-\s_\[\(].*)?$').firstMatch(fileName);
    if (titleEpisodeMatch != null) {
      final titlePart = titleEpisodeMatch.group(1)!.trim();
      final numberPart = titleEpisodeMatch.group(2)!;

      // Avoid matching years (e.g. "Movie 2023")
      if (numberPart.length == 4 && (numberPart.startsWith('19') || numberPart.startsWith('20'))) {
        return MediaType.movie;
      }

      // Check for fuzzy match between title part and parent directory
      if (_isFuzzyMatch(titlePart, parentDirName)) {
         return MediaType.tvShow;
      }
    }

    return MediaType.unknown;
  }

  ({String? title, int? year}) _extractTitleInfo(String fileName) {
    // Use the comprehensive smart extraction method
    return TitleProcessor.extractTitleUntilKeywords(fileName);
  }

  bool _isFuzzyMatch(String title1, String title2) {
    final n1 = _normalizeForFuzzyMatching(title1);
    final n2 = _normalizeForFuzzyMatching(title2);

    // 1. Direct containment (after normalization)
    if (n1.contains(n2) || n2.contains(n1)) return true;

    // 1b. Containment without spaces (handles Zom100 vs Zom 100)
    final n1NoSpace = n1.replaceAll(' ', '');
    final n2NoSpace = n2.replaceAll(' ', '');
    if (n1NoSpace.contains(n2NoSpace) || n2NoSpace.contains(n1NoSpace)) return true;

    // 2. Acronym matching (e.g. V-FE'sS -> Vivy Fluorite Eye's Song)
    // Create acronyms from the *original* strings (but cleaned of special chars)
    final a1 = _createAcronym(title1);
    final a2 = _createAcronym(title2);
    
    // If one is an acronym of the other
    if (a1.length > 2 && n2.replaceAll(RegExp(r'[^a-z]'), '').contains(a1)) return true;
    if (a2.length > 2 && n1.replaceAll(RegExp(r'[^a-z]'), '').contains(a2)) return true;

    // 3. Token overlap
    // If they share significant tokens
    final tokens1 = _tokenize(n1);
    final tokens2 = _tokenize(n2);
    final intersection = tokens1.intersection(tokens2);
    
    // If they share at least 50% of tokens of the shorter string
    final minTokens = tokens1.length < tokens2.length ? tokens1.length : tokens2.length;
    if (minTokens > 0 && intersection.length >= (minTokens / 2).ceil()) {
      return true;
    }

    return false;
  }

  String _normalizeForFuzzyMatching(String text) {
    return text.toLowerCase()
        .replaceAll(RegExp(r'[._\-]'), ' ') // Replace separators with space
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '') // Remove special chars
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize spaces
        .trim();
  }

  String _createAcronym(String text) {
    final words = text.toLowerCase()
        .replaceAll(RegExp(r"[^a-z0-9\s]"), "")
        .split(RegExp(r'\s+'));
    return words.where((w) => w.isNotEmpty).map((w) => w[0]).join('');
  }

  Set<String> _tokenize(String normalizedText) {
    return normalizedText.split(' ').where((t) => t.length > 1).toSet();
  }
}
