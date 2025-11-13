# IMPLEMENTATION.md

## Project Structure

```
renamer/
├── bin/
│   └── main.dart              # CLI entry point
├── lib/
│   ├── cli/
│   │   ├── args.dart          # Command-line argument parsing
│   │   └── commands.dart      # Command handlers (scan, rename, undo)
│   ├── core/
│   │   ├── scanner.dart       # Directory scanning and file detection
│   │   ├── detector.dart      # Media type detection (movie/show)
│   │   ├── renamer.dart       # File/folder renaming logic
│   │   └── undo.dart          # Undo system with JSON logging
│   ├── metadata/
│   │   ├── fetcher.dart       # External metadata API integration
│   │   ├── models.dart        # Data models for movies/shows/episodes
│   │   └── interactive.dart   # CLI prompts for user confirmation
│   ├── utils/
│   │   ├── filesystem.dart    # Cross-platform file operations
│   │   ├── validation.dart    # Path and name validation
│   │   └── logger.dart        # Structured logging
│   └── config.dart            # Configuration management
├── test/
│   ├── scanner_test.dart
│   ├── renamer_test.dart
│   └── undo_test.dart
├── pubspec.yaml
├── analysis_options.yaml
└── README.md
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
  final List<String> _videoExtensions = ['.mkv', '.mp4', '.avi', '.mov'];

  Future<List<MediaItem>> scanDirectory(String rootPath) async {
    final items = <MediaItem>[];

    await for (final entity in Directory(rootPath).list(recursive: true)) {
      if (entity is File && _isVideoFile(entity.path)) {
        final mediaItem = await _analyzeFile(entity.path);
        if (mediaItem != null) {
          items.add(mediaItem);
        }
      }
    }

    return items;
  }

  bool _isVideoFile(String path) =>
      _videoExtensions.contains(extension(path).toLowerCase());
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

### 7. Undo System (`lib/core/undo.dart`)

```dart
class UndoLogger {
  final String logPath;

  UndoLogger(this.logPath);

  Future<void> logRename(String originalPath, String newPath) async {
    final logEntry = {
      'original_path': originalPath,
      'new_path': newPath,
      'timestamp': DateTime.now().toIso8601String(),
    };

    final logFile = File(logPath);
    final existingLogs = await _readExistingLogs(logFile);

    existingLogs.add(logEntry);
    await logFile.writeAsString(jsonEncode(existingLogs));
  }

  Future<void> undo() async {
    final logFile = File(logPath);
    if (!await logFile.exists()) {
      throw Exception('No undo log found');
    }

    final logs = await _readExistingLogs(logFile);
    logs.sort((a, b) => b['timestamp'].compareTo(a['timestamp'])); // Reverse chronological

    for (final log in logs) {
      final originalPath = log['original_path'];
      final newPath = log['new_path'];

      if (await File(newPath).exists()) {
        await Directory(dirname(originalPath)).create(recursive: true);
        await File(newPath).rename(originalPath);
      }
    }

    await logFile.delete();
  }

  Future<List<Map<String, dynamic>>> _readExistingLogs(File logFile) async {
    if (!await logFile.exists()) return [];

    final content = await logFile.readAsString();
    return List<Map<String, dynamic>>.from(jsonDecode(content));
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

### Phase 1: Core Infrastructure
1. Set up Dart project with dependencies (`args`, `path`, `http`, `json_serializable`)
2. Implement CLI argument parsing
3. Create basic directory scanning
4. Set up logging and configuration management

### Phase 2: Media Detection and Analysis
1. Implement media type detection (movie vs TV show)
2. Add file pattern recognition for episodes/seasons
3. Create data models for movies, shows, episodes
4. Implement basic filename sanitization

### Phase 3: Renaming Engine
1. Build the core renaming logic for movies
2. Implement TV show season/episode structure creation
3. Add undo logging before any file operations
4. Handle edge cases (multi-part files, duplicates, etc.)

### Phase 4: Metadata Integration
1. Add external API integration (TMDB, TVDB)
2. Implement interactive CLI prompts
3. Add fuzzy matching for title suggestions
4. Support manual metadata entry

### Phase 5: Advanced Features
1. Implement undo functionality
2. Add dry-run mode with preview
3. Create configuration file support
4. Add progress indicators and error reporting

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