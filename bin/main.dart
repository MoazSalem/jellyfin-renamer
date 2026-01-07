import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:logging/logging.dart';
import 'package:renamer/cli/commands.dart';
import 'package:renamer/utils/logger.dart' as app_logger;

void main(List<String> args) async {
  final runner =
      CommandRunner<void>('renamer', 'Jellyfin media library renamer')
        ..argParser.addFlag(
          'verbose',
          abbr: 'v',
          negatable: false,
          help: 'Enable verbose logging.',
        )
        ..addCommand(ScanCommand(app_logger.AppLogger()))
        ..addCommand(RenameCommand(app_logger.AppLogger()))
        ..addCommand(RenameSingleCommand(app_logger.AppLogger()))
        ..addCommand(UndoCommand(app_logger.AppLogger()));

  try {
    final argResults = runner.parse(args);

    // Configure logger
    Logger.root.level = argResults['verbose'] as bool ? Level.ALL : Level.INFO;
    Logger.root.onRecord.listen((record) {
      stdout.writeln('${record.level.name}: ${record.message}');
    });

    final logger = app_logger.AppLogger();

    final runnerWithLogger =
        CommandRunner<void>('renamer', 'Jellyfin media library renamer')
          ..argParser.addFlag(
            'verbose',
            abbr: 'v',
            negatable: false,
            help: 'Enable verbose logging.',
          )
          ..addCommand(ScanCommand(logger))
          ..addCommand(RenameCommand(logger))
          ..addCommand(RenameSingleCommand(logger))
          ..addCommand(UndoCommand(logger));

    await runnerWithLogger.run(args);
  } on Object catch (error) {
    stderr.writeln('Error: $error');
    exit(1);
  }
}
