import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:renamer/cli/commands.dart';

void main(List<String> args) async {
  final runner = CommandRunner('renamer', 'Jellyfin media library renamer')
    ..addCommand(ScanCommand())
    ..addCommand(RenameCommand())
    ..addCommand(UndoCommand());

  try {
    await runner.run(args);
  } catch (error) {
    stderr.writeln('Error: $error');
    exit(1);
  }
}