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
    );
  }

  final app_logger.AppLogger _logger;

  @override
  final name = 'scan';
  @override
  final description = 'Scan directory for media files and detect types';

  @override
  List<String> get aliases => ['s'];

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
        _logger.info(
          '\nUnassociated Subtitles '
          '(${scanResult.unassociatedSubtitles.length}):',
        );
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

/// Base command for rename operations containing shared logic and configuration
abstract class BaseRenameCommand extends Command<void> {
  /// Creates a new base rename command instance.
  BaseRenameCommand(this.logger) {
    argParser
      ..addOption(
        'path',
        abbr: 'p',
        help: 'Root directory to process',
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
      )
      ..addOption(
        'mode',
        abbr: 'm',
        help: 'Rename mode (move, copy, hardlink, symlink)',
        defaultsTo: 'move',
        allowed: ['move', 'copy', 'hardlink', 'symlink'],
      )
      ..addOption(
        'output',
        abbr: 'o',
        help: 'Specific output directory for renamed files',
      );
  }

  /// The logger instance.
  final app_logger.AppLogger logger;

  /// Common execution logic for rename commands.
  ///
  /// [singleMode] - If true, enforces single show/movie constraints.
  Future<void> runCommon({bool singleMode = false}) async {
    var path = argResults?['path'] as String? ?? Directory.current.path;
    final rest = argResults?.rest;

    // Handle unquoted paths with spaces (e.g. -p Part1 Part2)
    if (rest != null && rest.isNotEmpty) {
      path = [path, ...rest].join(' ');
    }

    final dryRun = argResults?['dry-run'] as bool? ?? false;
    final interactive = argResults?['interactive'] as bool? ?? true;
    var logPath = argResults?['log'] as String? ?? 'rename_log.json';

    // If using default log path, place it in
    // the parent directory of the scan path
    // For single mode (Show/Movie folder), parent is the library folder.
    // For normal mode (Library folder), use the library folder's parent?
    // Maintaining original logic:
    if (logPath == 'rename_log.json') {
      if (singleMode) {
        logPath = p.join(p.dirname(path), 'rename_log.json');
      } else {
        logPath = p.join(p.dirname(p.dirname(path)), 'rename_log.json');
      }
    }

    final modeString = argResults?['mode'] as String? ?? 'move';
    final mode = switch (modeString) {
      'move' => RenameMode.move,
      'copy' => RenameMode.copy,
      'hardlink' => RenameMode.hardLink,
      'symlink' => RenameMode.symLink,
      _ => RenameMode.move,
    };
    final outputDir = argResults?['output'] as String?;

    final scanner = MediaScanner(logger: logger);
    final renamer = MediaRenamer(logger: logger);

    if (dryRun) {
      logger.info('DRY RUN MODE - No files will be modified');
    }

    try {
      logger.info('Scanning directory: $path');
      final scanResult = await scanner.scanDirectory(path);
      final items = scanResult.items;

      _reportUndetectedItems(scanResult);

      if (items.isEmpty) {
        // Only explicitly warn if single mode, otherwise
        // renamer handles empty list efficiently
        if (singleMode) {
          logger.info('No media items found in $path');
          return;
        }
      }

      if (singleMode) {
        _validateSingleMode(items);
      }

      if (items.isNotEmpty) {
        logger.info('Processing ${items.length} media items...');

        try {
          await renamer.processItems(
            items,
            scanRoot: path,
            outputDir: outputDir,
            dryRun: dryRun,
            interactive: interactive,
            mode: mode,
          );
          logger.info('All items processed successfully');
        } on Object catch (e) {
          logger.error('Failed to process items: $e');
          exit(1);
        }
      }

      logger.info(
        'Processing complete. ${dryRun ? "Use --dry-run=false "
                  "to apply changes." : ""}',
      );
    } on Object catch (e) {
      logger.error('Rename operation failed: $e');
      exit(1);
    }
  }

  void _reportUndetectedItems(ScanResult scanResult) {
    final items = scanResult.items;
    final unknownVideos = items
        .where((i) => i.type == MediaType.unknown)
        .toList();
    final tvShowsWithoutEpisodes = items
        .where((i) => i.type == MediaType.tvShow && i.episode == null)
        .toList();

    if (unknownVideos.isNotEmpty ||
        tvShowsWithoutEpisodes.isNotEmpty ||
        scanResult.unassociatedSubtitles.isNotEmpty) {
      logger.info('\n⚠️  UNDETECTED ITEMS ⚠️');
      if (unknownVideos.isNotEmpty) {
        logger.info('Unknown Videos (${unknownVideos.length}):');
        for (final item in unknownVideos) {
          logger.info('  ${item.path}');
        }
      }
      if (tvShowsWithoutEpisodes.isNotEmpty) {
        logger.info(
          'TV Shows with no episode info (${tvShowsWithoutEpisodes.length}):',
        );
        for (final item in tvShowsWithoutEpisodes) {
          logger.info('  ${item.path}');
        }
      }
      if (scanResult.unassociatedSubtitles.isNotEmpty) {
        logger.info(
          'Unassociated Subtitles '
          '(${scanResult.unassociatedSubtitles.length}):',
        );
        for (final sub in scanResult.unassociatedSubtitles) {
          logger.info('  $sub');
        }
      }
      logger.info('---------------------------------------------------\n');
    }
  }

  void _validateSingleMode(List<MediaItem> items) {
    if (items.isEmpty) return;

    final movies = items.where((i) => i.type == MediaType.movie).toList();
    final tvShows = items.where((i) => i.type == MediaType.tvShow).toList();

    if (movies.isNotEmpty && tvShows.isNotEmpty) {
      logger.error(
        'Mixed content detected. This command is for a '
        'single show OR a single movie.',
      );
      exit(1);
    }

    if (movies.length > 1) {
      final dirs = movies.map((m) => p.dirname(m.path)).toSet();
      if (dirs.length > 1) {
        logger.error(
          'Multiple movie directories detected. '
          'Please point to a single movie folder.',
        );
        exit(1);
      }
    }
  }
}

/// Command for renaming media files to comply with Jellyfin naming conventions.
class RenameCommand extends BaseRenameCommand {
  /// Creates a new rename command instance.
  RenameCommand(super.logger);

  @override
  final name = 'rename';
  @override
  final description = 'Rename media files to Jellyfin format';

  @override
  List<String> get aliases => ['r'];

  @override
  Future<void> run() async {
    await runCommon();
  }
}

/// Command for renaming a single show or movie.
class RenameSingleCommand extends BaseRenameCommand {
  /// Creates a new rename single command instance.
  RenameSingleCommand(super.logger);

  @override
  final name = 'rename-single';
  @override
  final description =
      'Rename a single show or movie by providing its parent folder path';

  @override
  List<String> get aliases => ['rs'];

  @override
  Future<void> run() async {
    await runCommon(singleMode: true);
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
      )
      ..addFlag(
        'dry-run',
        abbr: 'd',
        help: 'Alias for --preview',
        negatable: false,
      );
  }

  final app_logger.AppLogger _logger;

  @override
  final name = 'undo';
  @override
  final description = 'Revert previous rename operations';

  @override
  List<String> get aliases => ['u'];

  @override
  Future<void> run() async {
    final logPath = argResults?['log'] as String? ?? 'rename_log.json';
    final preview =
        (argResults?['preview'] as bool? ?? false) ||
        (argResults?['dry-run'] as bool? ?? false);

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
