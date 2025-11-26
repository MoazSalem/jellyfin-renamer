import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:renamer/core/renamer.dart';
import 'package:renamer/core/scanner.dart';
import 'package:renamer/core/undo.dart';
import 'package:renamer/metadata/models.dart';
import 'package:renamer/utils/logger.dart' as app_logger;

/// Command for scanning directories to detect media files and their types.
class ScanCommand extends Command<void> {
  /// Creates a new scan command instance.
  ScanCommand(this._logger) {
    argParser.addOption(
      'path',
      abbr: 'p',
      help: 'Root directory to scan',
      mandatory: false,
    );
  }

  final app_logger.AppLogger _logger;

  @override
  final name = 'scan';
  @override
  final description = 'Scan directory for media files and detect types';

  @override
  Future<void> run() async {
    final path = argResults?['path'] as String? ?? Directory.current.path;

    final scanner = MediaScanner(logger: _logger);
    _logger.info('Scanning directory: $path');

    try {
      final scanResult = await scanner.scanDirectory(path);
      final items = scanResult.items;

      _logger.info('Found ${items.length} media items:');
      for (final item in items) {
        _logger.info('  ${item.type}: ${item.path}');
        if (item.subtitlePaths.isNotEmpty) {
          _logger.info('    Subtitles: ${item.subtitlePaths.length}');
          for (final subtitlePath in item.subtitlePaths) {
            _logger.info('      $subtitlePath');
          }
        }
      }

      if (scanResult.unassociatedSubtitles.isNotEmpty) {
        _logger.info('\nUnassociated Subtitles (${scanResult.unassociatedSubtitles.length}):');
        for (final sub in scanResult.unassociatedSubtitles) {
          _logger.info('  $sub');
        }
      }
    } on Object catch (e) {
      _logger.error('Scan failed: $e');
      exit(1);
    }
  }
}

/// Command for renaming media files to comply with Jellyfin naming conventions.
class RenameCommand extends Command<void> {
  /// Creates a new rename command instance.
  RenameCommand(this._logger) {
    argParser
      ..addOption(
        'path',
        abbr: 'p',
        help: 'Root directory to process',
        mandatory: false,
      )
      ..addFlag(
        'dry-run',
        abbr: 'd',
        help: 'Preview changes without applying them',
      )
      ..addFlag(
        'interactive',
        abbr: 'i',
        help: 'Prompt for confirmation',
        defaultsTo: true,
      )
      ..addOption(
        'log',
        abbr: 'l',
        help: 'Path to undo log file',
        defaultsTo: 'rename_log.json',
      );
  }

  final app_logger.AppLogger _logger;

  @override
  final name = 'rename';
  @override
  final description = 'Rename media files to Jellyfin format';

  @override
  Future<void> run() async {
    var path = argResults?['path'] as String? ?? Directory.current.path;
    final rest = argResults?.rest;

    // Handle unquoted paths with spaces (e.g. -p Part1 Part2)
    if (rest != null && rest.isNotEmpty) {
      path = [path, ...rest].join(' ');
    }

    final dryRun = argResults?['dry-run'] as bool? ?? false;
    final interactive = argResults?['interactive'] as bool? ?? true;
    var logPath = argResults?['log'] as String? ?? 'rename_log.json';

    // If using default log path,
    // place it in the parent directory of the scan path
    if (logPath == 'rename_log.json') {
      logPath = p.join(p.dirname(p.dirname(path)), 'rename_log.json');
    }

    final scanner = MediaScanner(logger: _logger);
    final renamer = MediaRenamer(logger: _logger);

    if (dryRun) {
      _logger.info('DRY RUN MODE - No files will be modified');
    }

    try {
      _logger.info('Scanning directory: $path');
      final scanResult = await scanner.scanDirectory(path);
      final items = scanResult.items;

      // Check for undetected items
      final unknownVideos = items.where((i) => i.type == MediaType.unknown).toList();
      final tvShowsWithoutEpisodes = items.where((i) => i.type == MediaType.tvShow && i.episode == null).toList();
      
      if (unknownVideos.isNotEmpty || tvShowsWithoutEpisodes.isNotEmpty || scanResult.unassociatedSubtitles.isNotEmpty) {
          _logger.info('\n⚠️  UNDETECTED ITEMS ⚠️');
          if (unknownVideos.isNotEmpty) {
              _logger.info('Unknown Videos (${unknownVideos.length}):');
              for (final item in unknownVideos) _logger.info('  ${item.path}');
          }
          if (tvShowsWithoutEpisodes.isNotEmpty) {
              _logger.info('TV Shows with no episode info (${tvShowsWithoutEpisodes.length}):');
              for (final item in tvShowsWithoutEpisodes) _logger.info('  ${item.path}');
          }
          if (scanResult.unassociatedSubtitles.isNotEmpty) {
              _logger.info('Unassociated Subtitles (${scanResult.unassociatedSubtitles.length}):');
              for (final sub in scanResult.unassociatedSubtitles) _logger.info('  $sub');
          }
          _logger.info('---------------------------------------------------\n');
      }

      _logger.info('Processing ${items.length} media items...');

      try {
        await renamer.processItems(
          items,
          scanRoot: path,
          dryRun: dryRun,
          interactive: interactive,
        );
        _logger.info('All items processed successfully');
      } on Object catch (e) {
        _logger.error('Failed to process items: $e');
        exit(1);
      }

      _logger.info(
        'Processing complete. ${dryRun ? "Use --dry-run=false "
                  "to apply changes." : ""}',
      );
    } on Object catch (e) {
      _logger.error('Rename operation failed: $e');
      exit(1);
    }
  }
}

/// Command for renaming a single show or movie.
class RenameSingleCommand extends Command<void> {
  /// Creates a new rename single command instance.
  RenameSingleCommand(this._logger) {
    argParser
      ..addOption(
        'path',
        abbr: 'p',
        help: 'Path to the show or movie folder',
        mandatory: false,
      )
      ..addFlag(
        'dry-run',
        abbr: 'd',
        help: 'Preview changes without applying them',
      )
      ..addFlag(
        'interactive',
        abbr: 'i',
        help: 'Prompt for confirmation',
        defaultsTo: true,
      )
      ..addOption(
        'log',
        abbr: 'l',
        help: 'Path to undo log file',
        defaultsTo: 'rename_log.json',
      );
  }

  final app_logger.AppLogger _logger;

  @override
  final name = 'rename-single';
  @override
  final description = 'Rename a single show or movie by providing its parent folder path';

  @override
  Future<void> run() async {
    var path = argResults?['path'] as String? ?? Directory.current.path;
    final rest = argResults?.rest;

    // Handle unquoted paths with spaces (e.g. -p Part1 Part2)
    if (rest != null && rest.isNotEmpty) {
      path = [path, ...rest].join(' ');
    }

    final dryRun = argResults?['dry-run'] as bool? ?? false;
    final interactive = argResults?['interactive'] as bool? ?? true;
    var logPath = argResults?['log'] as String? ?? 'rename_log.json';

    // If using default log path,
    // place it in the parent directory of the scan path
    if (logPath == 'rename_log.json') {
      logPath = p.join(p.dirname(path), 'rename_log.json');
    }

    final scanner = MediaScanner(logger: _logger);
    final renamer = MediaRenamer(logger: _logger);

    if (dryRun) {
      _logger.info('DRY RUN MODE - No files will be modified');
    }

    try {
      _logger.info('Scanning directory: $path');
      final scanResult = await scanner.scanDirectory(path);
      final items = scanResult.items;

      // Check for undetected items
      final unknownVideos = items.where((i) => i.type == MediaType.unknown).toList();
      final tvShowsWithoutEpisodes = items.where((i) => i.type == MediaType.tvShow && i.episode == null).toList();
      
      if (unknownVideos.isNotEmpty || tvShowsWithoutEpisodes.isNotEmpty || scanResult.unassociatedSubtitles.isNotEmpty) {
          _logger.info('\n⚠️  UNDETECTED ITEMS ⚠️');
          if (unknownVideos.isNotEmpty) {
              _logger.info('Unknown Videos (${unknownVideos.length}):');
              for (final item in unknownVideos) _logger.info('  ${item.path}');
          }
          if (tvShowsWithoutEpisodes.isNotEmpty) {
              _logger.info('TV Shows with no episode info (${tvShowsWithoutEpisodes.length}):');
              for (final item in tvShowsWithoutEpisodes) _logger.info('  ${item.path}');
          }
          if (scanResult.unassociatedSubtitles.isNotEmpty) {
              _logger.info('Unassociated Subtitles (${scanResult.unassociatedSubtitles.length}):');
              for (final sub in scanResult.unassociatedSubtitles) _logger.info('  $sub');
          }
          _logger.info('---------------------------------------------------\n');
      }

      if (items.isEmpty) {
        _logger.info('No media items found in $path');
        return;
      }

      _logger.info('Found ${items.length} media items.');

      // Validate that we are dealing with a single show or movie
      final movies = items.where((i) => i.type == MediaType.movie).toList();
      final tvShows = items.where((i) => i.type == MediaType.tvShow).toList();

      if (movies.isNotEmpty && tvShows.isNotEmpty) {
        _logger.error('Mixed content detected. This command is for a single show OR a single movie.');
        exit(1);
      }

      if (movies.length > 1) {
         // It's possible to have multiple movie files for one movie (e.g. parts), but usually this implies multiple movies.
         // For now, we'll warn but proceed if they seem to be related, or just rely on the renamer to handle it.
         // However, the requirement is "single movie".
         // Let's check if they are likely the same movie (e.g. same directory).
         final dirs = movies.map((m) => p.dirname(m.path)).toSet();
         if (dirs.length > 1) {
             _logger.error('Multiple movie directories detected. Please point to a single movie folder.');
             exit(1);
         }
      }
      
      // For TV shows, we want to ensure it's likely one show.
      // The grouper logic in MediaRenamer will handle grouping, but here we want to enforce "single".
      // We can rely on the MediaRenamer's single show detection logic implicitly, 
      // or we can check if the renamer considers it a single show scan.
      // But MediaRenamer.processItems doesn't expose that check directly before processing.
      // We will trust the user provided a specific folder and let MediaRenamer handle it,
      // but we pass the specific path as scanRoot.

      _logger.info('Processing items...');

      try {
        await renamer.processItems(
          items,
          scanRoot: path,
          dryRun: dryRun,
          interactive: interactive,
        );
        _logger.info('All items processed successfully');
      } on Object catch (e) {
        _logger.error('Failed to process items: $e');
        exit(1);
      }

      _logger.info(
        'Processing complete. ${dryRun ? "Use --dry-run=false "
                  "to apply changes." : ""}',
      );
    } on Object catch (e) {
      _logger.error('Rename operation failed: $e');
      exit(1);
    }
  }
}

/// Command for undoing previous rename operations.
class UndoCommand extends Command<void> {
  /// Creates a new undo command instance.
  UndoCommand(this._logger) {
    argParser
      ..addOption(
        'log',
        abbr: 'l',
        help: 'Path to undo log file',
        defaultsTo: 'rename_log.json',
      )
      ..addFlag(
        'preview',
        abbr: 'p',
        help: 'Show what will be undone without applying',
      );
  }

  final app_logger.AppLogger _logger;

  @override
  final name = 'undo';
  @override
  final description = 'Revert previous rename operations';

  @override
  Future<void> run() async {
    final logPath = argResults?['log'] as String? ?? 'rename_log.json';
    final preview = argResults?['preview'] as bool? ?? false;

    final undoLogger = UndoLogger(logPath, logger: _logger);

    try {
      if (preview) {
        _logger.info('Previewing undo operations from: $logPath');
        final operations = await undoLogger.getLoggedOperations();
        _logger.info('Found ${operations.length} operations to undo:');
        for (final op in operations) {
          _logger.info('  ${op.newPath} -> ${op.originalPath}');
        }
      } else {
        _logger.info('Undoing operations from: $logPath');
        await undoLogger.undo();
        _logger.info('Undo complete.');
      }
    } on Object catch (e) {
      _logger.error('Undo failed: $e');
      exit(1);
    }
  }
}
