import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:renamer/metadata/models.dart';
import 'package:renamer/core/detector.dart';

class MediaScanner {
  final List<String> _videoExtensions = ['.mkv', '.mp4', '.avi', '.mov', '.m4v', '.wmv'];
  final MediaDetector _detector = MediaDetector();

  Future<List<MediaItem>> scanDirectory(String rootPath) async {
    final items = <MediaItem>[];
    final rootDir = Directory(rootPath);

    if (!await rootDir.exists()) {
      throw Exception('Directory does not exist: $rootPath');
    }

    await for (final entity in rootDir.list(recursive: true)) {
      if (entity is File && _isVideoFile(entity.path)) {
        final mediaItem = await _analyzeFile(entity.path, rootPath);
        if (mediaItem != null) {
          items.add(mediaItem);
        }
      }
    }

    return items;
  }

  bool _isVideoFile(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    return _videoExtensions.contains(extension);
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