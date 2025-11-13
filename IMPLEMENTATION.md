# IMPLEMENTATION.md

## Project Structure

```
renamer/
├── bin/
│   └── main.dart              # CLI entry point
├── lib/
│   ├── cli/
│   │   └── commands.dart      # Command handlers (scan, rename, undo)
│   ├── core/
│   │   ├── scanner.dart       # Directory scanning, file detection, and subtitle association
│   │   ├── detector.dart      # Media type detection (movie/show)
│   │   ├── renamer.dart       # File/folder renaming logic with subtitle support
│   │   └── undo.dart          # Enhanced undo system with human-readable logs
│   ├── metadata/
│   │   ├── models.dart        # Data models for movies/shows/episodes with subtitle paths
│   │   └── interactive.dart   # CLI prompts for user confirmation
│   ├── config/
│   │   └── release_tags.dart  # Release tag filtering configuration
│   └── utils/
│       └── logger.dart        # Structured logging
├── test/
│   └── renamer_test.dart      # Unit tests
├── pubspec.yaml
├── analysis_options.yaml
├── AGENTS.md                  # Development guidelines
├── DESIGN.md                  # Design specifications
├── IMPLEMENTATION.md          # Implementation details
├── README.md                  # User documentation
└── .gitignore                 # Git ignore rules
```

## Core Components Implementation

### 1. CLI Entry Point (`bin/main.dart`)

```dart
import 'package:args/command_runner.dart';
import 'package:renamer/cli/commands.dart';

void main(List<String> args) {
  final runner = CommandRunner('renamer', 'Jellyfin media library renamer')
    ..addCommand(ScanCommand())
    ..addCommand(RenameCommand())
    ..addCommand(UndoCommand());

  runner.run(args).catchError((error) {
    print('Error: $error');
    exit(1);
  });
}
```

### 2. Command-Line Arguments (`lib/cli/args.dart`)

```dart
class RenameArgs {
  final String rootPath;
  final bool dryRun;
  final bool interactive;
  final String? configFile;
  final bool undo;
  final String? undoLogPath;

  RenameArgs({
    required this.rootPath,
    this.dryRun = true,
    this.interactive = true,
    this.configFile,
    this.undo = false,
    this.undoLogPath = 'rename_log.json',
  });
}
```

### 3. Directory Scanner (`lib/core/scanner.dart`)

```dart
class MediaScanner {
  final List<String> _videoExtensions = ['.mkv', '.mp4', '.avi', '.mov', '.m4v', '.wmv'];
  final List<String> _subtitleExtensions = ['.srt', '.sub', '.ass', '.ssa', '.vtt'];

  Future<List<MediaItem>> scanDirectory(String rootPath) async {
    final videoFiles = <String>[];
    final subtitleFiles = <String>[];

    // Collect all video and subtitle files
    await for (final entity in Directory(rootPath).list(recursive: true)) {
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

  bool _isVideoFile(String path) =>
      _videoExtensions.contains(extension(path).toLowerCase());

  bool _isSubtitleFile(String path) =>
      _subtitleExtensions.contains(extension(path).toLowerCase());

  List<String> _findAssociatedSubtitles(String videoPath, List<String> subtitleFiles) {
    // Intelligent subtitle association logic
    // - Exact filename match
    // - Episode code match
    // - Close name match
    // - Directory-based association
  }
}
```

### 4. Media Type Detection (`lib/core/detector.dart`)

```dart
enum MediaType { movie, tvShow, unknown }

class MediaDetector {
  MediaType detectType(String directoryPath, List<String> files) {
    // Check for season folders (S01, Season 1, etc.)
    final hasSeasons = files.any((file) =>
        RegExp(r'S\d{2}|Season \d+').hasMatch(file));

    // Check for episode patterns in filenames
    final hasEpisodes = files.any((file) =>
        RegExp(r'S\d{2}E\d{2}').hasMatch(file));

    if (hasSeasons || hasEpisodes) {
      return MediaType.tvShow;
    }

    // Single video file in directory suggests movie
    final videoFiles = files.where((f) =>
        ['.mkv', '.mp4', '.avi'].contains(extension(f))).toList();

    return videoFiles.length == 1 ? MediaType.movie : MediaType.unknown;
  }
}
```

### 5. Metadata Models (`lib/metadata/models.dart`)

```dart
enum MediaType { movie, tvShow, unknown }

class MediaItem {
  final String path;
  final MediaType type;
  final String? detectedTitle;
  final int? detectedYear;
  final List<String> subtitlePaths;

  MediaItem({
    required this.path,
    required this.type,
    this.detectedTitle,
    this.detectedYear,
    List<String>? subtitlePaths,
  }) : subtitlePaths = subtitlePaths ?? [];
}

class Movie {
  final String title;
  final int? year;
  final String? imdbId;
  final String? tmdbId;

  Movie({
    required this.title,
    this.year,
    this.imdbId,
    this.tmdbId,
  });

  String get jellyfinName =>
      year != null ? '$title ($year)' : title;
}

class TvShow {
  final String title;
  final int? year;
  final String? tvdbId;
  final String? tmdbId;
  final List<Season> seasons;

  TvShow({
    required this.title,
    this.year,
    this.tvdbId,
    this.tmdbId,
    required this.seasons,
  });

  String get jellyfinName =>
      year != null ? '$title ($year)' : title;
}

class Season {
  final int number;
  final List<Episode> episodes;

  Season({required this.number, required this.episodes});
}

class Episode {
  final int seasonNumber;
  final int episodeNumber;
  final String? title;

  Episode({
    required this.seasonNumber,
    required this.episodeNumber,
    this.title,
  });

  String get episodeCode =>
      'S${seasonNumber.toString().padLeft(2, '0')}E${episodeNumber.toString().padLeft(2, '0')}';
}
```

### 6. Renaming Logic (`lib/core/renamer.dart`)

```dart
class MediaRenamer {
  final UndoLogger _undoLogger;

  MediaRenamer(this._undoLogger);

  Future<void> renameMovie(Movie movie, String currentPath, String targetDir) async {
    final sanitizedTitle = _sanitizeFilename(movie.jellyfinName);
    final movieDir = join(targetDir, sanitizedTitle);
    final newVideoPath = join(movieDir, '$sanitizedTitle${extension(currentPath)}');

    // Create directory if needed
    await Directory(movieDir).create(recursive: true);

    // Log for undo before renaming
    await _undoLogger.logRename(currentPath, newVideoPath);

    // Perform rename
    await File(currentPath).rename(newVideoPath);
  }

  Future<void> renameTvShow(TvShow show, String currentPath, String targetDir) async {
    final sanitizedTitle = _sanitizeFilename(show.jellyfinName);
    final showDir = join(targetDir, sanitizedTitle);

    await Directory(showDir).create(recursive: true);

    for (final season in show.seasons) {
      final seasonDir = join(showDir, 'Season ${season.number.toString().padLeft(2, '0')}');
      await Directory(seasonDir).create(recursive: true);

      for (final episode in season.episodes) {
        final episodeName = _formatEpisodeName(show, episode);
        final newPath = join(seasonDir, '$episodeName${extension(currentPath)}');

        await _undoLogger.logRename(currentPath, newPath);
        await File(currentPath).rename(newPath);
      }
    }
  }

  String _sanitizeFilename(String name) {
    return name.replaceAll(RegExp(r'[<>:"|?*]'), '').replaceAll('/', '-');
  }
}
```

### 7. Enhanced Undo System (`lib/core/undo.dart`)

```dart
class UndoLogger {
  final String logPath;
  final app_logger.AppLogger _logger;

  UndoLogger(this.logPath, {app_logger.AppLogger? logger})
      : _logger = logger ?? app_logger.AppLogger();

  Future<void> logRename(String originalPath, String newPath) async {
    final logEntry = RenameOperation(
      originalPath: originalPath,
      newPath: newPath,
      timestamp: DateTime.now(),
    );

    final logFile = File(logPath);
    final existingLogs = await _readExistingLogs(logFile);
    existingLogs.add(logEntry);

    // Write human-readable header and entries, followed by JSON data
    final buffer = StringBuffer();

    // Header with instructions
    buffer.writeln('# Jellyfin Media Renamer - Undo Log');
    buffer.writeln('# Generated on: ${DateTime.now().toIso8601String()}');
    buffer.writeln('# To undo: renamer undo --log "$logPath"');
    buffer.writeln();

    // Human-readable entries (most recent first)
    final sortedLogs = List<RenameOperation>.from(existingLogs)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    for (final log in sortedLogs) {
      buffer.writeln(log.timestamp.toIso8601String());
      buffer.writeln('  FROM: ${log.originalPath}');
      buffer.writeln('  TO:   ${log.newPath}');
      buffer.writeln();
    }

    // Separator and JSON data
    buffer.writeln('# ==========================================');
    buffer.writeln('# JSON data for machine processing');
    buffer.writeln('# ==========================================');
    const encoder = JsonEncoder.withIndent('  ');
    buffer.writeln(encoder.convert(existingLogs.map((e) => e.toJson()).toList()));

    await logFile.writeAsString(buffer.toString());
  }

  Future<void> undo() async {
    final logFile = File(logPath);
    if (!await logFile.exists()) {
      throw Exception('No undo log found at: $logPath');
    }

    final logs = await _readExistingLogs(logFile);
    logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    var successCount = 0;
    var totalOperations = logs.length;

    try {
      for (final log in logs) {
        if (await File(log.newPath).exists()) {
          await Directory(path.dirname(log.originalPath)).create(recursive: true);
          await File(log.newPath).rename(log.originalPath);
          successCount++;
          _logger.info('Undid: ${log.newPath} -> ${log.originalPath}');
        } else {
          _logger.warning('File no longer exists: ${log.newPath}');
          totalOperations--; // Don't count as failure
        }
      }

      // Clean up empty directories
      final targetDirs = <String>{};
      for (final log in logs) {
        targetDirs.add(log.newPath);
      }

      for (final filePath in targetDirs) {
        final dir = Directory(path.dirname(filePath)).parent;
        if (await _isDirectoryEmpty(dir.path)) {
          await dir.delete(recursive: true);
          _logger.info('Deleted empty directory: ${dir.path}');
        }
      }

      // Only delete log on complete success
      if (successCount == totalOperations) {
        await logFile.delete();
        _logger.info('Undo completed successfully.');
      } else {
        _logger.warning('Undo partially completed ($successCount/$totalOperations). Log preserved.');
      }
    } catch (e) {
      _logger.error('Undo failed: $e');
      _logger.warning('Log file preserved for retry.');
      rethrow;
    }
  }

  Future<List<RenameOperation>> _readExistingLogs(File logFile) async {
    if (!await logFile.exists()) return [];

    try {
      final content = await logFile.readAsString();
      final lines = content.split('\n');

      // Find JSON section
      final jsonStartIndex = lines.indexWhere((line) => line.contains('# JSON data'));
      if (jsonStartIndex == -1) {
        // Fallback for old format
        final jsonList = jsonDecode(content) as List<dynamic>;
        return jsonList.map((json) => RenameOperation.fromJson(json)).toList();
      }

      // Skip comment lines to find JSON
      var jsonContentStart = jsonStartIndex + 1;
      while (jsonContentStart < lines.length && lines[jsonContentStart].trim().startsWith('#')) {
        jsonContentStart++;
      }

      final jsonContent = lines.sublist(jsonContentStart).join('\n').trim();
      final jsonList = jsonDecode(jsonContent) as List<dynamic>;
      return jsonList.map((json) => RenameOperation.fromJson(json)).toList();
    } catch (e) {
      _logger.warning('Could not read undo log: $e');
      return [];
    }
  }

  Future<bool> _isDirectoryEmpty(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) return false;

    try {
      final list = dir.list(recursive: true, followLinks: false);
      return await list.isEmpty;
    } catch (e) {
      return false;
    }
  }
}
```

### 8. Interactive CLI (`lib/metadata/interactive.dart`)

```dart
class InteractivePrompt {
  final Stdin _stdin = stdin;
  final Stdout _stdout = stdout;

  Future<Movie?> promptMovieDetails(List<Movie> suggestions) async {
    _stdout.writeln('Found multiple movie matches:');
    for (var i = 0; i < suggestions.length; i++) {
      _stdout.writeln('${i + 1}. ${suggestions[i].jellyfinName}');
    }
    _stdout.writeln('${suggestions.length + 1}. Enter manually');
    _stdout.write('Select option: ');

    final input = _readLine().trim();
    final choice = int.tryParse(input);

    if (choice != null && choice > 0 && choice <= suggestions.length) {
      return suggestions[choice - 1];
    } else if (choice == suggestions.length + 1) {
      return await _promptManualMovieEntry();
    }

    return null;
  }

  Future<Movie> _promptManualMovieEntry() async {
    _stdout.write('Enter movie title: ');
    final title = _readLine().trim();

    _stdout.write('Enter year (optional): ');
    final yearInput = _readLine().trim();
    final year = int.tryParse(yearInput);

    return Movie(title: title, year: year);
  }

  String _readLine() {
    return _stdin.readLineSync() ?? '';
  }
}
```

## Implementation Phases

### ✅ Phase 1: Core Infrastructure (Completed)
1. ✅ Set up Dart project with dependencies (`args`, `path`, `json_serializable`)
2. ✅ Implement CLI argument parsing and commands
3. ✅ Create directory scanning with video and subtitle detection
4. ✅ Set up logging and configuration management

### ✅ Phase 2: Media Detection and Analysis (Completed)
1. ✅ Implement media type detection (movie vs TV show)
2. ✅ Add file pattern recognition for episodes/seasons
3. ✅ Create data models for movies, shows, episodes with subtitle support
4. ✅ Implement intelligent subtitle association algorithms
5. ✅ Implement basic filename sanitization

### ✅ Phase 3: Renaming Engine (Completed)
1. ✅ Build the core renaming logic for movies with subtitle support
2. ✅ Implement TV show season/episode structure creation with subtitles
3. ✅ Add enhanced undo logging with human-readable format
4. ✅ Handle edge cases (multi-part files, duplicates, etc.)
5. ✅ Directory-based TV show episode grouping

### 🔄 Phase 4: Metadata Integration (In Progress)
1. 🔄 Add external API integration (TMDB, TVDB) - Basic structure ready
2. ✅ Implement interactive CLI prompts with subtitle awareness
3. 🔄 Add fuzzy matching for title suggestions
4. ✅ Support manual metadata entry

### ✅ Phase 5: Advanced Features (Completed)
1. ✅ Implement comprehensive undo functionality with error recovery
2. ✅ Add dry-run mode with detailed preview
3. ✅ Create configuration file support (release tags)
4. ✅ Add progress indicators and error reporting
5. ✅ Cross-platform compatibility (Windows/Linux/macOS)

## Testing Strategy

```dart
// Example test for renamer
void main() {
  group('MediaRenamer', () {
    test('sanitizes illegal characters', () {
      final renamer = MediaRenamer(MockUndoLogger());
      final result = renamer.sanitizeFilename('Movie: Title? <Test>');
      expect(result, 'Movie- Title- -Test-');
    });

    test('creates correct Jellyfin movie structure', () async {
      final movie = Movie(title: 'Inception', year: 2010);
      final renamer = MediaRenamer(MockUndoLogger());

      await renamer.renameMovie(movie, '/old/path.mkv', '/Movies');

      // Verify directory structure created
      expect(await Directory('/Movies/Inception (2010)').exists(), isTrue);
      expect(await File('/Movies/Inception (2010)/Inception (2010).mkv').exists(), isTrue);
    });
  });
}
```

## Error Handling

- **File System Errors**: Permission denied, file not found, disk full
- **Network Errors**: API timeouts, rate limiting for metadata fetching
- **Validation Errors**: Invalid paths, malformed filenames, duplicate names
- **User Input Errors**: Invalid selections, malformed manual entries

All errors should be caught, logged, and presented to user with actionable recovery suggestions.</content>
<parameter name="filePath">C:\Users\Moaz\Music\Renamer\IMPLEMENTATION.md