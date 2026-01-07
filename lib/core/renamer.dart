import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:renamer/core/grouper.dart';
import 'package:renamer/core/undo.dart';
import 'package:renamer/metadata/interactive.dart';
import 'package:renamer/metadata/models.dart';
import 'package:renamer/utils/logger.dart' as app_logger;
import 'package:renamer/utils/sort_utils.dart';
import 'package:renamer/utils/title_processor.dart';

/// The mode of operation for the renamer.
enum RenameMode {
  /// Rename (move) files.
  move,

  /// Copy files.
  copy,

  /// Create hard links.
  hardLink,

  /// Create symbolic links.
  symLink,
}

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
  final TvShowGrouper _grouper = TvShowGrouper();
  final List<RenameOperation> _plannedOperations = [];
  final Map<String, UndoLogger> _loggers = {};
  late String? _scanRoot;
  bool _isSingleShowScan = false;

  /// Processes a list of media items,
  /// renaming them according to Jellyfin conventions.
  /// [items] - List of media items to process
  /// [dryRun] - If true, only shows what would be done without making changes
  /// [interactive] - If true, prompts user for confirmation and metadata input
  Future<void> processItems(
    List<MediaItem> items, {
    required String scanRoot,
    bool dryRun = false,
    bool interactive = true,
    RenameMode mode = RenameMode.move,
  }) async {
    _logger.debug(
      'processItems called with ${items.length} items. dryRun=$dryRun, '
      'interactive=$interactive, mode=$mode',
    );
    _scanRoot = scanRoot;
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

    // Detect if this is a single show scan
    final allTvShowGuesses = _grouper.groupShows(tvShowItems).keys;
    if (movies.isEmpty && allTvShowGuesses.length == 1) {
      _isSingleShowScan = true;
    } else if (tvShowItems.isEmpty && movies.length == 1) {
      _isSingleShowScan = true;
    } else {
      _isSingleShowScan = false;
    }

    // Process movies individually
    for (final movie in movies) {
      await _processMovie(movie, dryRun: dryRun, interactive: interactive);
    }

    // Group and process TV shows
    if (tvShowItems.isNotEmpty) {
      final groupedShows = _grouper.groupShows(tvShowItems);

      for (final entry in groupedShows.entries) {
        final directoryGroupsWithOriginalNames =
            entry.value; // List of ({originalShowName, items})

        // Extract the original casing show name for display in prompts
        final displayShowName =
            directoryGroupsWithOriginalNames.first.originalShowName;

        if (directoryGroupsWithOriginalNames.length > 1 && interactive) {
          final confirmed = await _interactive.confirmGroup(
            displayShowName, // Use original casing for display
            directoryGroupsWithOriginalNames
                .map((e) => e.items)
                .toList(), // Pass only the items for display
          );
          if (confirmed) {
            final allItems = directoryGroupsWithOriginalNames
                .expand((e) => e.items)
                .toList();
            await _processTvShowGroupFromItems(
              allItems,
              showNameGuess: displayShowName, // Pass original casing
              dryRun: dryRun,
              interactive: interactive,
            );
          } else {
            // Process each directory group separately
            for (final groupWithOriginalName
                in directoryGroupsWithOriginalNames) {
              await _processTvShowGroupFromItems(
                groupWithOriginalName.items,
                showNameGuess: groupWithOriginalName
                    .originalShowName, // Pass original casing
                dryRun: dryRun,
                interactive: interactive,
              );
            }
          }
        } else {
          // Process single directory group
          final groupWithOriginalName = directoryGroupsWithOriginalNames.first;
          await _processTvShowGroupFromItems(
            groupWithOriginalName.items,
            showNameGuess:
                groupWithOriginalName.originalShowName, // Pass original casing
            dryRun: dryRun,
            interactive: interactive,
          );
        }
      }
    }

    // Show preview if dry run or interactive
    if (dryRun || interactive) {
      _showPreview(dryRun: dryRun, interactive: interactive);
    }

    // Execute operations if not dry run and confirmed
    if (!dryRun) {
      if (!interactive || await _interactive.confirmExecution()) {
        await _executeOperations(mode);
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
    required String scanRoot,
    bool dryRun = false,
    bool interactive = true,
    RenameMode mode = RenameMode.move,
  }) async {
    await processItems(
      [item],
      scanRoot: scanRoot,
      dryRun: dryRun,
      interactive: interactive,
      mode: mode,
    );
  }

  String _getOutputBaseDirectory() {
    if (_isSingleShowScan) {
      return path.dirname(_scanRoot!);
    } else {
      return _scanRoot!;
    }
  }

  String _getTargetDirectory() {
    return _getOutputBaseDirectory();
  }

  Future<void> _processMovie(
    MediaItem item, {
    bool dryRun = false,
    bool interactive = true,
  }) async {
    // For now, create a basic movie object from detected info
    // In a full implementation, this would fetch from TMDB/IMDB
    var movieTitle = item.detectedTitle ?? _extractTitleFromPath(item.path);
    var movieYear = item.detectedYear;
    _logger.debug('Detected year for ${item.path}: ${item.detectedYear}');

    // Check if title looks reasonable, prompt for better extraction if not
    if (interactive && !TitleProcessor.isTitleReasonable(movieTitle)) {
      final fileName = path.basenameWithoutExtension(item.path);
      final extractionResult = await _interactive.promptTitleExtraction(
        fileName,
        movieTitle,
      );
      if (extractionResult == null) return; // User skipped
      if (extractionResult.title != null) {
        movieTitle = extractionResult.title!;
      }
      if (extractionResult.year != null) {
        movieYear = extractionResult.year;
      }
    }

    final movie = Movie(
      title: movieTitle,
      year: movieYear,
    );

    var confirmedMovie = movie;
    if (interactive) {
      // In interactive mode, prompt user to confirm/edit metadata
      final promptedMovie = await _interactive.promptMovieDetails(item, [
        movie,
      ]);
      if (promptedMovie == null) return; // User cancelled
      confirmedMovie = promptedMovie;
    }

    final targetDir = _getTargetDirectory();
    _planRenameMovie(confirmedMovie, item.path, targetDir, item.subtitlePaths);
  }

  Future<void> _processTvShowGroupFromItems(
    List<MediaItem> showItems, {
    String? showNameGuess,
    bool dryRun = false,
    bool interactive = true,
  }) async {
    if (showItems.isEmpty) return;

    // Gather show name candidates
    final candidates = <({String? title, int? year})>[];
    if (showNameGuess != null) {
      candidates.add((title: showNameGuess, year: null));
    }
    final firstItem = showItems.first;
    final extractedFromFile = TitleProcessor.extractTitleUntilKeywords(
      path.basename(firstItem.path),
    );
    if (extractedFromFile.title != null) {
      candidates.add(extractedFromFile);
    }
    final dirName = path.basename(path.dirname(firstItem.path));
    final extractedFromDir = TitleProcessor.extractTitleUntilKeywords(dirName);
    if (extractedFromDir.title != null) {
      candidates.add(extractedFromDir);
    }

    // Remove duplicates
    final uniqueCandidates = candidates.toSet().toList();

    var finalShowName =
        showNameGuess ?? _extractShowNameFromItem(showItems.first);
    var finalYear = showItems.first.detectedYear;

    // If interactive, allow user to confirm/correct the show name
    if (interactive) {
      final confirmedShow = await _interactive.promptShowSelectionWithFiles(
        uniqueCandidates,
        showItems,
      );
      if (confirmedShow == null) return; // User skipped
      finalShowName = confirmedShow.title;
      finalYear = confirmedShow.year;
    }

    // Extract all season/episode info from all files
    final seasonsMap = <int, List<Episode>>{};
    final fileEpisodeMap = <String, Episode>{};
    final episodeSubtitleMap =
        <String, List<String>>{}; // video path -> subtitle paths

    for (final item in showItems) {
      final episodeInfo = item.episode;
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

    final show = TvShow(
      title: finalShowName,
      year: finalYear,
      seasons: seasons,
    );

    final targetDir = _getTargetDirectory();
    _planRenameTvShowGroup(show, fileEpisodeMap, episodeSubtitleMap, targetDir);
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
    _planRenameSubtitles(
      subtitlePaths,
      movie.jellyfinName,
      null,
      movieDir,
    );
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

      final subtitles = episodeSubtitleMap[currentPath] ?? [];
      _planRenameSubtitles(
        subtitles,
        show.jellyfinName,
        episode.episodeCode,
        seasonDir,
      );
    }
  }

  void _planRenameSubtitles(
    List<String> subtitlePaths,
    String baseName,
    String? episodeCode,
    String targetDir,
  ) {
    for (final subtitlePath in subtitlePaths) {
      final subtitleExtension = path.extension(subtitlePath);
      final String subtitleFileName;
      if (episodeCode != null) {
        subtitleFileName = '$baseName $episodeCode.default$subtitleExtension';
      } else {
        subtitleFileName = '$baseName.default$subtitleExtension';
      }
      final newSubtitlePath = path.join(targetDir, subtitleFileName);
      _plannedOperations.add(RenameOperation(subtitlePath, newSubtitlePath));
    }
  }

  Future<void> _executeOperations(RenameMode mode) async {
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

    // Execute operations
    for (final op in _plannedOperations) {
      var targetPath = op.targetPath;
      final sourceFile = File(op.sourcePath);

      // Check for collision
      if (File(targetPath).existsSync()) {
        // If source and target are the same file, allow it for move/copy/hardlink logic if paths differ.
        // But for hardlink, they technically point to same data.
        if (path.canonicalize(op.sourcePath) != path.canonicalize(targetPath)) {
          _logger.warning(
            'Target file already exists: $targetPath. Appending suffix.',
          );
          // Find unique name
          var counter = 1;
          final ext = path.extension(targetPath);
          final base = path.withoutExtension(targetPath);
          while (File(targetPath).existsSync()) {
            targetPath = '$base ($counter)$ext';
            counter++;
          }
        }
      }

      final logger = _getLoggerForOperation(op);
      if (logger != null && mode == RenameMode.move) {
        await logger.logRename(op.sourcePath, targetPath);
      }

      try {
        switch (mode) {
          case RenameMode.move:
            await sourceFile.rename(targetPath);
          case RenameMode.copy:
            await sourceFile.copy(targetPath);
          case RenameMode.symLink:
            await Link(targetPath).create(op.sourcePath);
          case RenameMode.hardLink:
            await _createHardLink(op.sourcePath, targetPath);
        }
      } catch (e) {
        _logger.error(
          'Failed to ${mode.name} ${op.sourcePath} to $targetPath: $e',
        );
        // Continue with other files? Or rethrow?
        // For now, log error and continue
      }
    }

    // Clean up empty source directories ONLY if moving
    if (mode == RenameMode.move) {
      final sourceDirs = <String>{};
      for (final op in _plannedOperations) {
        sourceDirs.add(path.dirname(op.sourcePath));
      }

      for (final dir in sourceDirs) {
        if (await _isDirectoryEmpty(dir)) {
          // Check if this is the current working directory
          final normalizedDir = path.canonicalize(dir);
          final normalizedCwd = path.canonicalize(Directory.current.path);

          if (normalizedDir == normalizedCwd) {
            _logger.info(
              '\n⚠️  Skipping deletion of empty directory because it is '
              'the current working directory: $dir\n',
            );
            continue;
          } else {
            _logger.debug(
              'Directory $dir ($normalizedDir) is not CWD ($normalizedCwd)',
            );
          }

          try {
            await Directory(dir).delete(recursive: true);
            _logger.info('Deleted empty directory: $dir');
          } on FileSystemException catch (e) {
            _logger.warning(
              'Failed to delete empty directory $dir: ${e.message}',
            );
          }
        }
      }
    }
  }

  Future<void> _createHardLink(String source, String target) async {
    if (Platform.isWindows) {
      final result = await Process.run('cmd', [
        '/c',
        'mklink',
        '/H',
        target,
        source,
      ]);
      if (result.exitCode != 0) {
        throw Exception('mklink failed: ${result.stderr}');
      }
    } else {
      final result = await Process.run('ln', [source, target]);
      if (result.exitCode != 0) {
        throw Exception('ln failed: ${result.stderr}');
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
      ..sort((a, b) => SortUtils.naturalCompare(a.key, b.key));

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

  String _extractTitleFromPath(String filePath) {
    final fileName = path.basenameWithoutExtension(filePath);
    // Remove common patterns and return the base name
    return fileName.split(RegExp(r'[.\-\s]+'))[0];
  }
}
