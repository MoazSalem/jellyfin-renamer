import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:renamer/core/renamer.dart';
import 'package:renamer/core/scanner.dart';
import 'package:renamer/core/undo.dart';
import 'package:renamer/utils/logger.dart' as app_logger;

/// Command for scanning directories to detect media files and their types.
class ScanCommand extends Command<void> {
  /// Creates a new scan command instance.
  ScanCommand() {
    argParser
      ..addOption(
        'path',
        abbr: 'p',
        help: 'Root directory to scan',
        mandatory: true,
      )
      ..addFlag('verbose', abbr: 'v', help: 'Show detailed output');
  }

  @override
  final name = 'scan';
  @override
  final description = 'Scan directory for media files and detect types';

  @override
  Future<void> run() async {
    final path = argResults?['path'] as String;
    final verbose = argResults?['verbose'] as bool? ?? false;

    final scanner = MediaScanner();
    final logger = app_logger.AppLogger(verbose: verbose)
      ..info('Scanning directory: $path');

    try {
      final items = await scanner.scanDirectory(path);

      logger.info('Found $items.length media items:');
      for (final item in items) {
        logger.info('  ${item.type}: ${item.path}');
        if (item.subtitlePaths.isNotEmpty) {
          logger.info('    Subtitles: ${item.subtitlePaths.length}');
          for (final subtitlePath in item.subtitlePaths) {
            logger.info('      $subtitlePath');
          }
        }
      }
    } on Object catch (e) {
      logger.error('Scan failed: $e');
      exit(1);
    }
  }
}

/// Command for renaming media files to comply with Jellyfin naming conventions.
class RenameCommand extends Command<void> {
  /// Creates a new rename command instance.
  RenameCommand() {
    argParser
      ..addOption(
        'path',
        abbr: 'p',
        help: 'Root directory to process',
        mandatory: true,
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
      ..addFlag('verbose', abbr: 'v', help: 'Show detailed output');
  }

  @override
  final name = 'rename';
  @override
  final description = 'Rename media files to Jellyfin format';

  @override
  Future<void> run() async {
    final path = argResults?['path'] as String;
    final dryRun = argResults?['dry-run'] as bool? ?? false;
    final interactive = argResults?['interactive'] as bool? ?? true;
    var logPath = argResults?['log'] as String? ?? 'rename_log.json';
    final verbose = argResults?['verbose'] as bool? ?? false;

    // If using default log path,
    // place it in the parent directory of the scan path
    if (logPath == 'rename_log.json') {
      logPath = p.join(p.dirname(p.dirname(path)), 'rename_log.json');
    }

    final logger = app_logger.AppLogger(verbose: verbose);
    final scanner = MediaScanner();
    final renamer = MediaRenamer(logger: logger);

    if (dryRun) {
      logger.info('DRY RUN MODE - No files will be modified');
    }

    try {
      logger.info('Scanning directory: $path');
      final items = await scanner.scanDirectory(path);

      logger.info('Processing ${items.length} media items...');

      try {
        await renamer.processItems(
          items,
          scanRoot: path,
          dryRun: dryRun,
          interactive: interactive,
        );
        logger.info('All items processed successfully');
      } on Object catch (e) {
        logger.error('Failed to process items: $e');
        exit(1);
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
}

/// Command for undoing previous rename operations.
class UndoCommand extends Command<void> {
  /// Creates a new undo command instance.
  UndoCommand() {
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
      ..addFlag('verbose', abbr: 'v', help: 'Show detailed output');
  }

  @override
  final name = 'undo';
  @override
  final description = 'Revert previous rename operations';

  @override
  Future<void> run() async {
    final logPath = argResults?['log'] as String? ?? 'rename_log.json';
    final preview = argResults?['preview'] as bool? ?? false;
    final verbose = argResults?['verbose'] as bool? ?? false;

    final logger = app_logger.AppLogger(verbose: verbose);
    final undoLogger = UndoLogger(logPath, logger: logger);

    try {
      if (preview) {
        logger.info('Previewing undo operations from: $logPath');
        final operations = await undoLogger.getLoggedOperations();
        logger.info('Found ${operations.length} operations to undo:');
        for (final op in operations) {
          logger.info('  ${op.newPath} -> ${op.originalPath}');
        }
      } else {
        logger.info('Undoing operations from: $logPath');
        await undoLogger.undo();
        logger.info('Undo complete.');
      }
    } on Object catch (e) {
      logger.error('Undo failed: $e');
      exit(1);
    }
  }
}
