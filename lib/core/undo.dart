import 'dart:convert';
import 'dart:io';

import 'package:renamer/metadata/models.dart';
import 'package:renamer/utils/logger.dart' as app_logger;

/// Logger for tracking rename operations to enable undo functionality.
class UndoLogger {
  /// Creates a new undo logger instance.
  ///
  /// [logPath] - Path to the log file
  /// [logger] - Optional logger instance.
  /// If not provided, a default logger is used.
  UndoLogger(this.logPath, {app_logger.AppLogger? logger})
    : _logger = logger ?? app_logger.AppLogger();

  /// Path to the log file where operations are stored.
  final String logPath;

  final app_logger.AppLogger _logger;

  /// Logs a rename operation to the undo log file.
  ///
  /// [originalPath] - The original file path before renaming
  /// [newPath] - The new file path after renaming
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
    final buffer = StringBuffer()
      // Header
      ..writeln('# Jellyfin Media Renamer - Undo Log')
      ..writeln(
        '# This file contains rename operations that can be undone.',
      )
      ..writeln('# Generated on: ${DateTime.now().toIso8601String()}')
      ..writeln('#')
      ..writeln(
        '# To undo these operations, run: renamer undo --log "$logPath"',
      )
      ..writeln('#')
      ..writeln('# Operations performed:')
      ..writeln();

    // Human-readable entries (sorted by timestamp, most recent first)
    final sortedLogs = List<RenameOperation>.from(existingLogs)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    for (final log in sortedLogs) {
      buffer
        ..writeln(log.timestamp.toIso8601String())
        ..writeln('  FROM: ${log.originalPath}')
        ..writeln('  TO:   ${log.newPath}')
        ..writeln();
    }

    // Separator between human-readable and JSON data
    buffer
      ..writeln('# ==========================================')
      ..writeln(
        '# JSON data for machine processing (do not edit below this line)',
      )
      ..writeln('# ==========================================');

    // JSON data (pretty-printed for readability)
    const encoder = JsonEncoder.withIndent('  ');
    buffer.writeln(
      encoder.convert(existingLogs.map((e) => e.toJson()).toList()),
    );

    await logFile.writeAsString(buffer.toString());
  }

  /// Retrieves all logged rename operations from the log file.
  Future<List<RenameOperation>> getLoggedOperations() {
    final logFile = File(logPath);
    return _readExistingLogs(logFile);
  }

  /// Undoes all rename operations recorded in the log file.
  Future<void> undo() async {
    final logFile = File(logPath);
    if (!logFile.existsSync()) {
      throw Exception('No undo log found at: $logPath');
    }

    final logs = await _readExistingLogs(logFile);

    // Sort by timestamp descending (most recent first)
    logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    var successCount = 0;
    var totalOperations = logs.length;

    try {
      for (final log in logs) {
        if (File(log.newPath).existsSync()) {
          // Ensure target directory exists
          await Directory(log.originalPath).parent.create(recursive: true);
          await File(log.newPath).rename(log.originalPath);
          successCount++;
          _logger.info('Undid: ${log.newPath} -> ${log.originalPath}');
        } else {
          _logger.warning(
            'File no longer exists at ${log.newPath}, skipping undo',
          );
          // Still count as processed (not an error)
          totalOperations--;
        }
      }

      // Clean up empty directories recursively
      final processedDirs = <String>{};
      for (final log in logs) {
        var currentDir = Directory(log.newPath).parent;
        // Walk up the directory tree
        // and collect all directories that might become empty
        while (currentDir.path != currentDir.parent.path) {
          processedDirs.add(currentDir.path);
          currentDir = currentDir.parent;
        }
      }

      // Sort by depth (deepest first)
      // to ensure we delete child directories before parents
      final sortedDirs = processedDirs.toList()
        ..sort(
          (a, b) => b
              .split(Platform.pathSeparator)
              .length
              .compareTo(a.split(Platform.pathSeparator).length),
        );

      for (final dirPath in sortedDirs) {
        final dir = Directory(dirPath);
        if (await _isDirectoryEmpty(dir.path)) {
          try {
            await dir.delete(recursive: true);
            _logger.info('Deleted empty directory: ${dir.path}');
          } on Object catch (e) {
            // Ignore errors when deleting directories
            // (might not be empty due to concurrent operations)
            _logger.warning('Could not delete directory ${dir.path}: $e');
          }
        }
      }

      // Only remove the log file if all operations succeeded
      if (successCount == totalOperations) {
        await logFile.delete();
        _logger.info('Undo completed successfully. Log file removed.');
      } else {
        _logger.warning(
          'Undo completed partially ($successCount/$totalOperations operations). Log file preserved for retry.',
        );
      }
    } on Object catch (e) {
      _logger
        ..error('Undo failed during operation: $e')
        ..warning('Log file preserved. You can retry the undo operation.');
      rethrow;
    }
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

  Future<List<RenameOperation>> _readExistingLogs(File logFile) async {
    if (!logFile.existsSync()) {
      return [];
    }

    try {
      final content = await logFile.readAsString();
      final lines = content.split('\n');

      // Find the JSON section (after the separator)
      final jsonStartIndex = lines.indexWhere(
        (line) => line.contains('# JSON data for machine processing'),
      );
      if (jsonStartIndex == -1) {
        // Fallback: try to parse the entire content as JSON
        final jsonList = jsonDecode(content) as List<dynamic>;
        return jsonList
            .map(
              (json) => RenameOperation.fromJson(json as Map<String, dynamic>),
            )
            .toList();
      }

      // Find the actual JSON content (skip comment lines after the separator)
      var jsonContentStart = jsonStartIndex + 1;
      while (jsonContentStart < lines.length &&
          lines[jsonContentStart].trim().startsWith('#')) {
        jsonContentStart++;
      }

      if (jsonContentStart >= lines.length) {
        throw const FormatException('No JSON content found after separator');
      }

      // Extract JSON content from the first line after the separator
      final jsonContent = lines.sublist(jsonContentStart).join('\n').trim();
      final jsonList = jsonDecode(jsonContent) as List<dynamic>;
      return jsonList
          .map((json) => RenameOperation.fromJson(json as Map<String, dynamic>))
          .toList();
    } on Object catch (e) {
      // If log file is corrupted, return empty list
      _logger.warning('Could not read undo log: $e');
      return [];
    }
  }
}
