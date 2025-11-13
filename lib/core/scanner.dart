import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:renamer/config/subtitle_filters.dart';
import 'package:renamer/metadata/models.dart';
import 'package:renamer/core/detector.dart';

class MediaScanner {
  final List<String> _videoExtensions = ['.mkv', '.mp4', '.avi', '.mov', '.m4v', '.wmv'];
  final List<String> _subtitleExtensions = ['.srt', '.sub', '.ass', '.ssa', '.vtt'];
  final MediaDetector _detector = MediaDetector();

  Future<List<MediaItem>> scanDirectory(String rootPath) async {
    final videoFiles = <String>[];
    final subtitleFiles = <String>[];
    final rootDir = Directory(rootPath);

    if (!await rootDir.exists()) {
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
    for (final videoPath in videoFiles) {
      final mediaItem = await _analyzeFile(videoPath, rootPath);
      if (mediaItem != null) {
        // Find associated subtitle files
        final associatedSubtitles = _findAssociatedSubtitles(videoPath, subtitleFiles);
        final mediaItemWithSubtitles = MediaItem(
          path: mediaItem.path,
          type: mediaItem.type,
          detectedTitle: mediaItem.detectedTitle,
          detectedYear: mediaItem.detectedYear,
          subtitlePaths: associatedSubtitles,
        );
        items.add(mediaItemWithSubtitles);
      }
    }

    return items;
  }

  bool _isVideoFile(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    return _videoExtensions.contains(extension);
  }

  bool _isSubtitleFile(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    return _subtitleExtensions.contains(extension);
  }

  List<String> _findAssociatedSubtitles(String videoPath, List<String> subtitleFiles) {
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
    final videoEpisodeMatch = RegExp(r'S(\d{1,2})E(\d{1,2})', caseSensitive: false).firstMatch(videoName);
    final subtitleEpisodeMatch = RegExp(r'S(\d{1,2})E(\d{1,2})', caseSensitive: false).firstMatch(subtitleName);

    if (videoEpisodeMatch != null && subtitleEpisodeMatch != null) {
      final videoEpisode = 'S${videoEpisodeMatch.group(1)}E${videoEpisodeMatch.group(2)}';
      final subtitleEpisode = 'S${subtitleEpisodeMatch.group(1)}E${subtitleEpisodeMatch.group(2)}';
      if (videoEpisode == subtitleEpisode) return true;
    }

    // Check if they have the same episode code even if one doesn't have it extracted
    if (videoEpisodeMatch != null || subtitleEpisodeMatch != null) {
      final episodeCode = videoEpisodeMatch != null
          ? 'S${videoEpisodeMatch.group(1)}E${videoEpisodeMatch.group(2)}'
          : 'S${subtitleEpisodeMatch!.group(1)}E${subtitleEpisodeMatch.group(2)}';
      if (videoName.contains(episodeCode) && subtitleName.contains(episodeCode)) return true;
    }

    // Common words matching - check if they share significant words
    final videoWords = _extractSignificantWords(normalizedVideo);
    final subtitleWords = _extractSignificantWords(normalizedSubtitle);

    // If they share at least 2 significant words, consider them related
    final commonWords = videoWords.intersection(subtitleWords);
    if (commonWords.length >= 2) return true;

    // One name contains a significant portion of the other
    if (normalizedSubtitle.contains(normalizedVideo) || normalizedVideo.contains(normalizedSubtitle)) return true;

    return false;
  }

  String _normalizeForSubtitleMatching(String name) {
    // Remove common quality indicators and extra info
    var normalized = name;
    for (final indicator in qualityIndicators) {
      normalized = normalized.replaceAll(RegExp(r'\b' + RegExp.escape(indicator) + r'\b', caseSensitive: false), '');
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
      // Keep words that are not just numbers, single chars, or common quality terms
      return word.length > 2 &&
             !RegExp(r'^\d+$').hasMatch(word) &&
             !subtitleFilterWords.contains(word.toLowerCase());
    }).toSet();
  }

  Future<MediaItem?> _analyzeFile(String filePath, String rootPath) async {
    try {
      final fileName = path.basenameWithoutExtension(filePath);

      // Detect media type based on filename patterns
      final mediaType = _detectTypeFromFilename(fileName);

      // Extract basic title and year from filename
      final titleInfo = _extractTitleInfo(fileName);

      return MediaItem(
        path: filePath,
        type: mediaType,
        detectedTitle: titleInfo.title,
        detectedYear: titleInfo.year,
      );
    } catch (e) {
      // Skip files that can't be analyzed
      return null;
    }
  }

  MediaType _detectTypeFromFilename(String fileName) {
    // Check for episode patterns (SxxExx) - indicates TV shows
    if (RegExp(r'S\d{1,2}E\d{1,2}', caseSensitive: false).hasMatch(fileName)) {
      return MediaType.tvShow;
    }

    // Check for year patterns (19xx, 20xx) - indicates movies
    if (RegExp(r'\b(19|20)\d{2}\b').hasMatch(fileName)) {
      return MediaType.movie;
    }

    // Default to unknown
    return MediaType.unknown;
  }

  ({String? title, int? year}) _extractTitleInfo(String fileName) {
    // Remove common video file suffixes and quality indicators
    var cleanName = fileName
        .replaceAll(RegExp(r'\.(1080p|720p|4k|bluray|web-dl|hdr|hevc|x264).*', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\[\(].*?[\]\)]'), '') // Remove brackets and parentheses content
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize spaces
        .trim();

    // Remove trailing dots
    cleanName = cleanName.replaceAll(RegExp(r'\.+$'), '');

    // Try to extract year
    final yearMatch = RegExp(r'\b(19|20)\d{2}\b').firstMatch(cleanName);
    int? year;
    if (yearMatch != null) {
      year = int.tryParse(yearMatch.group(0)!);
      cleanName = cleanName.replaceFirst(RegExp(r'\b' + yearMatch.group(0)! + r'\b'), '').trim();
    }

    // Clean up dots used as separators
    cleanName = cleanName.replaceAll('.', ' ').trim();

    return (title: cleanName.isNotEmpty ? cleanName : null, year: year);
  }
}