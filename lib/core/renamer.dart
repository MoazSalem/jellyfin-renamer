import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:renamer/config/file_extensions.dart';
import 'package:renamer/core/undo.dart';
import 'package:renamer/metadata/interactive.dart';
import 'package:renamer/metadata/models.dart';
import 'package:renamer/utils/logger.dart' as app_logger;

/// Represents a single rename operation with source and target paths.
class RenameOperation {
  /// Creates a new rename operation.
  RenameOperation(this.sourcePath, this.targetPath);

  /// The original file path before renaming.
  final String sourcePath;

  /// The target file path after renaming.
  final String targetPath;
}

/// Main class responsible for renaming media files
/// according to Jellyfin conventions.
class MediaRenamer {
  /// Creates a new media renamer instance.
  ///
  /// [logger] logger instance, a default logger is used if not provided.
  MediaRenamer({app_logger.AppLogger? logger})
    : _logger = logger ?? app_logger.AppLogger();
  final InteractivePrompt _interactive = InteractivePrompt();
  final app_logger.AppLogger _logger;
  String? _tvFolderName;
  final List<RenameOperation> _plannedOperations = [];
  final Map<String, UndoLogger> _loggers = {};

  /// Processes a list of media items,
  /// renaming them according to Jellyfin conventions.
  /// [items] - List of media items to process
  /// [dryRun] - If true, only shows what would be done without making changes
  /// [interactive] - If true, prompts user for confirmation and metadata input
  Future<void> processItems(
    List<MediaItem> items, {
    bool dryRun = false,
    bool interactive = true,
  }) async {
    _plannedOperations.clear();

    // Group items by type
    final movies = <MediaItem>[];
    final tvShowItems = <MediaItem>[];

    for (final item in items) {
      switch (item.type) {
        case MediaType.movie:
          movies.add(item);
        case MediaType.tvShow:
          tvShowItems.add(item);
        case MediaType.unknown:
          // Skip unknown types
          break;
      }
    }

    // Prompt for TV folder name if interactive and there are TV shows
    if (interactive && tvShowItems.isNotEmpty && _tvFolderName == null) {
      _tvFolderName = await _interactive.promptTvFolderName();
    }

    // Process movies individually (usually one per folder)
    for (final movie in movies) {
      await _processMovie(movie, dryRun: dryRun, interactive: interactive);
    }

    // Group TV show items by directory structure
    if (tvShowItems.isNotEmpty) {
      final groupedByDirectory = <String, List<MediaItem>>{};

      for (final item in tvShowItems) {
        // Group by the directory containing the episode files
        final itemDir = path.dirname(item.path);
        final itemDirName = path.basename(itemDir);

        // If it's a season directory (S01, Season 1, etc.),
        // group by parent directory
        final isSeasonDir =
            itemDirName.toLowerCase().startsWith('season') ||
            RegExp(r'^s\d+$', caseSensitive: false).hasMatch(itemDirName);
        final groupKey = isSeasonDir ? path.dirname(itemDir) : itemDir;

        groupedByDirectory.putIfAbsent(groupKey, () => []).add(item);
      }

      // Process each directory group
      for (final group in groupedByDirectory.values) {
        await _processTvShowGroupFromItems(
          group,
          dryRun: dryRun,
          interactive: interactive,
        );
      }
    }

    // Show preview if dry run or interactive
    if (dryRun || interactive) {
      _showPreview(dryRun: dryRun, interactive: interactive);
    }

    // Execute operations if not dry run and confirmed
    if (!dryRun) {
      if (!interactive || await _interactive.confirmExecution()) {
        await _executeOperations();
      }
    }
  }

  /// Processes a single media item,
  /// renaming it according to Jellyfin conventions.
  ///
  /// [item] - The media item to process
  /// [dryRun] - If true, only shows what would be done without making changes
  /// [interactive] - If true, prompts user for confirmation and metadata input
  Future<void> processItem(
    MediaItem item, {
    bool dryRun = false,
    bool interactive = true,
  }) async {
    await processItems([item], dryRun: dryRun, interactive: interactive);
  }

  Future<void> _processMovie(
    MediaItem item, {
    bool dryRun = false,
    bool interactive = true,
  }) async {
    // For now, create a basic movie object from detected info
    // In a full implementation, this would fetch from TMDB/IMDB
    final movie = Movie(
      title: item.detectedTitle ?? _extractTitleFromPath(item.path),
      year: item.detectedYear,
    );

    var confirmedMovie = movie;
    if (interactive) {
      // In interactive mode, prompt user to confirm/edit metadata
      final promptedMovie = await _interactive.promptMovieDetails([movie]);
      if (promptedMovie == null) return; // User cancelled
      confirmedMovie = promptedMovie;
    }

    final targetDir = _getTargetDirectory(item.path, 'Movies');
    _planRenameMovie(confirmedMovie, item.path, targetDir, item.subtitlePaths);
  }

  Future<void> _processTvShowGroupFromItems(
    List<MediaItem> showItems, {
    String? showName,
    bool dryRun = false,
    bool interactive = true,
  }) async {
    if (showItems.isEmpty) return;

    // Prioritize show name from parent directory
    final itemDir = path.dirname(showItems.first.path);
    final itemDirName = path.basename(itemDir);
    final isSeasonDir =
        itemDirName.toLowerCase().startsWith('season') ||
        RegExp(r'^s\d+$', caseSensitive: false).hasMatch(itemDirName);
    final showDir = isSeasonDir ? path.dirname(itemDir) : itemDir;
    final parsedDir = _parseShowNameFromText(path.basename(showDir));
    final finalShowName = parsedDir.title.isNotEmpty
        ? parsedDir.title
        : (showName ?? _extractShowNameFromItem(showItems.first));
    final finalYear = parsedDir.year ?? showItems.first.detectedYear;

    // Extract all season/episode info from all files
    final seasonsMap = <int, List<Episode>>{};
    final fileEpisodeMap = <String, Episode>{};
    final episodeSubtitleMap =
        <String, List<String>>{}; // video path -> subtitle paths

    for (final item in showItems) {
      final episodeInfo = _extractEpisodeInfo(item.path);
      if (episodeInfo != null) {
        seasonsMap
            .putIfAbsent(episodeInfo.seasonNumber, () => [])
            .add(episodeInfo);
        fileEpisodeMap[item.path] = episodeInfo;
        episodeSubtitleMap[item.path] = item.subtitlePaths;
      }
    }

    final seasons = seasonsMap.entries
        .map((e) => Season(number: e.key, episodes: e.value))
        .toList();

    var show = TvShow(
      title: finalShowName,
      year: finalYear,
      seasons: seasons,
    );

    if (interactive) {
      final fullName = path.basename(showDir);
      final confirmedShow = await _interactive.promptTvShowDetailsWithFiles(
        show,
        showItems,
        fullName: fullName,
      );
      if (confirmedShow == null) return;
      show = confirmedShow;
    }

    final targetDir = _getTargetDirectory(showItems.first.path, 'TV Shows');
    _planRenameTvShowGroup(show, fileEpisodeMap, episodeSubtitleMap, targetDir);
  }

  ({String title, int? year}) _parseShowNameFromText(String text) {
    // Clean up the text
    var cleanText = text
        .replaceAll('.', ' ')
        .replaceAll('_', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Remove season information
    cleanText = cleanText
        .replaceAll(RegExp(r'\bseason\s*\d+\b', caseSensitive: false), '')
        .trim();
    cleanText = cleanText
        .replaceAll(RegExp(r'\bs\d+\b', caseSensitive: false), '')
        .trim();

    // Remove common release info
    for (final tag in filenameFilterWords) {
      cleanText = cleanText
          .replaceAll(
            RegExp(r'\b' + RegExp.escape(tag) + r'\b', caseSensitive: false),
            '',
          )
          .trim();
    }
    cleanText = cleanText.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Clean up trailing separators (like " - ", " -", "- ")
    cleanText = cleanText.replaceAll(RegExp(r'\s*-\s*$'), '').trim();
    cleanText = cleanText.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Try to extract year in parentheses (common in directory names)
    final parenYearMatch = RegExp(r'\((\d{4})\)$').firstMatch(cleanText);
    int? year;
    if (parenYearMatch != null) {
      year = int.tryParse(parenYearMatch.group(1)!);
      cleanText = cleanText.replaceFirst(parenYearMatch.group(0)!, '').trim();
    } else {
      // Try to extract year without parentheses
      final yearMatch = RegExp(r'\b(19|20)\d{2}\b').firstMatch(cleanText);
      if (yearMatch != null) {
        year = int.tryParse(yearMatch.group(0)!);
        cleanText = cleanText.replaceFirst(yearMatch.group(0)!, '').trim();
      }
    }

    return (title: cleanText, year: year);
  }

  String _extractShowNameFromItem(MediaItem item) {
    final fileName = path.basenameWithoutExtension(item.path);
    final episodeMatch = RegExp(
      r'S(\d{1,2})E(\d{1,2})',
      caseSensitive: false,
    ).firstMatch(fileName);
    if (episodeMatch != null) {
      final title = fileName.replaceFirst(episodeMatch.group(0)!, '').trim();
      return title.replaceAll('.', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    }
    return item.detectedTitle ?? '';
  }

  void _planRenameMovie(
    Movie movie,
    String currentPath,
    String targetDir,
    List<String> subtitlePaths,
  ) {
    final movieDir = path.join(targetDir, movie.jellyfinName);
    final logPath = path.join(movieDir, 'rename_log.json');
    _loggers.putIfAbsent(movieDir, () => UndoLogger(logPath, logger: _logger));

    // Plan video file rename
    final fileName = '${movie.jellyfinName}${path.extension(currentPath)}';
    final newPath = path.join(movieDir, fileName);
    _plannedOperations.add(RenameOperation(currentPath, newPath));

    // Plan subtitle file renames
    for (final subtitlePath in subtitlePaths) {
      final subtitleExtension = path.extension(subtitlePath);
      final subtitleFileName =
          '${movie.jellyfinName}.default$subtitleExtension';
      final newSubtitlePath = path.join(movieDir, subtitleFileName);
      _plannedOperations.add(RenameOperation(subtitlePath, newSubtitlePath));
    }
  }

  void _planRenameTvShowGroup(
    TvShow show,
    Map<String, Episode> fileEpisodeMap,
    Map<String, List<String>> episodeSubtitleMap,
    String targetDir,
  ) {
    // Determine the show directory:
    // prefer existing directories to avoid duplication
    final expectedShowDir = path.join(targetDir, show.jellyfinName);

    String showDir;
    if (Directory(expectedShowDir).existsSync()) {
      // If the expected show directory already exists, use it
      showDir = expectedShowDir;
    } else if (path.basename(targetDir) == show.jellyfinName) {
      // If targetDir is already named after the show, use it
      showDir = targetDir;
    } else {
      // Otherwise, create the expected structure
      showDir = expectedShowDir;
    }

    final logPath = path.join(showDir, 'rename_log.json');
    _loggers.putIfAbsent(showDir, () => UndoLogger(logPath, logger: _logger));

    for (final entry in fileEpisodeMap.entries) {
      final currentPath = entry.key;
      final episode = entry.value;

      final seasonDir = path.join(
        showDir,
        'Season ${episode.seasonNumber.toString().padLeft(2, '0')}',
      );
      final episodeName =
          '${show.jellyfinName} '
          '${episode.episodeCode}${path.extension(currentPath)}';
      final newPath = path.join(seasonDir, episodeName);

      _plannedOperations.add(RenameOperation(currentPath, newPath));

      // Plan subtitle renames for this episode
      final subtitles = episodeSubtitleMap[currentPath] ?? [];
      for (final subtitlePath in subtitles) {
        final subtitleExtension = path.extension(subtitlePath);
        final subtitleFileName =
            '${show.jellyfinName} '
            '${episode.episodeCode}.default$subtitleExtension';
        final newSubtitlePath = path.join(seasonDir, subtitleFileName);
        _plannedOperations.add(RenameOperation(subtitlePath, newSubtitlePath));
      }
    }
  }

  Future<void> _executeOperations() async {
    // Group operations by directories to create them first
    final directories = <String>{};

    for (final op in _plannedOperations) {
      final dir = path.dirname(op.targetPath);
      directories.add(dir);
    }

    // Create all directories
    for (final dir in directories) {
      await Directory(dir).create(recursive: true);
    }

    // Execute renames
    for (final op in _plannedOperations) {
      final logger = _getLoggerForOperation(op);
      if (logger != null) {
        await logger.logRename(op.sourcePath, op.targetPath);
      }
      await File(op.sourcePath).rename(op.targetPath);
    }

    // Clean up empty source directories
    final sourceDirs = <String>{};
    for (final op in _plannedOperations) {
      sourceDirs.add(path.dirname(op.sourcePath));
    }

    for (final dir in sourceDirs) {
      if (await _isDirectoryEmpty(dir)) {
        await Directory(dir).delete(recursive: true);
        _logger.info('Deleted empty directory: $dir');
      }
    }
  }

  UndoLogger? _getLoggerForOperation(RenameOperation op) {
    for (final entry in _loggers.entries) {
      if (op.targetPath.startsWith(entry.key + path.separator) ||
          op.targetPath.startsWith('${entry.key}/')) {
        return entry.value;
      }
    }
    return null;
  }

  Future<bool> _isDirectoryEmpty(String dirPath) async {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return false;

    try {
      final list = dir.list(recursive: true, followLinks: false);
      return await list.isEmpty;
    } on Exception catch (_) {
      // If can't list, assume not empty
      return false;
    }
  }

  void _showPreview({bool dryRun = false, bool interactive = true}) {
    if (_plannedOperations.isEmpty) {
      _logger.info('No operations planned.');
      return;
    }

    _logger.info('\n📁 Preview of final structure:');
    final tree = _buildTreeStructure();
    _logger.info(tree);

    if (dryRun) {
      _logger.info('\nThis is a dry run. No files will be modified.');
    }
  }

  String _buildTreeStructure() {
    // Group operations by their root directory
    final rootDirs = <String, dynamic>{};

    for (final op in _plannedOperations) {
      final parts = path.split(op.targetPath);
      var current = rootDirs;

      for (var i = 0; i < parts.length; i++) {
        final part = parts[i];
        final isFile = i == parts.length - 1;

        if (!current.containsKey(part)) {
          current[part] = isFile ? null : <String, dynamic>{};
        }

        if (!isFile) {
          current = current[part] as Map<String, dynamic>;
        }
      }
    }

    // Build the tree string
    final buffer = StringBuffer();
    _buildTreeString(rootDirs, buffer, '', '');
    return buffer.toString();
  }

  void _buildTreeString(
    Map<String, dynamic> node,
    StringBuffer buffer,
    String prefix,
    String childPrefix,
  ) {
    final entries = node.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final isLast = i == entries.length - 1;
      final connector = isLast ? '└── ' : '├── ';
      final nextPrefix = isLast ? '    ' : '│   ';

      buffer.writeln('$prefix$connector${entry.key}');

      if (entry.value is Map<String, dynamic>) {
        _buildTreeString(
          entry.value as Map<String, dynamic>,
          buffer,
          '$childPrefix$nextPrefix',
          '$childPrefix$nextPrefix',
        );
      }
    }
  }

  String _getTargetDirectory(String sourcePath, String mediaType) {
    // For now, create media type subdirectory in the same parent directory
    // In a full implementation, this could be configurable
    final parentDir = path.dirname(path.dirname(sourcePath));

    // For TV shows, use the configured folder name or skip if empty
    if (mediaType == 'TV Shows') {
      final folderName = _tvFolderName ?? 'TV Shows';
      if (folderName.isEmpty) {
        return parentDir; // Skip the TV Shows folder
      }
      return path.join(parentDir, folderName);
    }

    return path.join(parentDir, mediaType);
  }

  String _extractTitleFromPath(String filePath) {
    final fileName = path.basenameWithoutExtension(filePath);
    // Remove common patterns and return the base name
    return fileName.split(RegExp(r'[.\-\s]+'))[0];
  }

  Episode? _extractEpisodeInfo(String filePath) {
    final fileName = path.basenameWithoutExtension(filePath);
    final episodeMatch = RegExp(
      r'S(\d{1,2})E(\d{1,2})',
      caseSensitive: false,
    ).firstMatch(fileName);
    if (episodeMatch != null) {
      final seasonNum = int.parse(episodeMatch.group(1)!);
      final episodeNum = int.parse(episodeMatch.group(2)!);
      return Episode(seasonNumber: seasonNum, episodeNumber: episodeNum);
    }
    return null;
  }
}
