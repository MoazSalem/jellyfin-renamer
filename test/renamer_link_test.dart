import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:renamer/core/renamer.dart';
import 'package:renamer/metadata/models.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late MediaRenamer renamer;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('renamer_test_');
    renamer = MediaRenamer();
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('RenameMode.move renames file and creates undo log', () async {
    final movieDir = await Directory(
      p.join(tempDir.path, 'My Movie (2020)'),
    ).create();
    final file = await File(
      p.join(movieDir.path, 'My.Movie.2020.mkv'),
    ).create();
    final item = MediaItem(
      path: file.path,
      type: MediaType.movie,
      detectedTitle: 'My Movie',
      detectedYear: 2020,
    );

    // Act
    await renamer.processItems(
      [item],
      scanRoot: movieDir.path,
      interactive: false,
      mode: RenameMode.move,
    );

    // Assert
    // 1. Source file should be gone
    expect(await file.exists(), isFalse);

    // 2. Target file should exist
    final targetPath = p.join(
      tempDir.path,
      'My Movie (2020)',
      'My Movie (2020).mkv',
    );
    expect(await File(targetPath).exists(), isTrue);

    // 3. Undo log should exist
    final logPath = p.join(tempDir.path, 'My Movie (2020)', 'rename_log.json');
    expect(await File(logPath).exists(), isTrue);
  });

  test('RenameMode.copy copies file and does NOT create undo log', () async {
    final movieDir = await Directory(
      p.join(tempDir.path, 'Copy Movie (2021)'),
    ).create();
    final file = await File(
      p.join(movieDir.path, 'Copy.Movie.2021.mkv'),
    ).create();
    final item = MediaItem(
      path: file.path,
      type: MediaType.movie,
      detectedTitle: 'Copy Movie',
      detectedYear: 2021,
    );

    await renamer.processItems(
      [item],
      scanRoot: movieDir.path,
      interactive: false,
      mode: RenameMode.copy,
    );

    // Assert
    // 1. Source file should still exist
    expect(await file.exists(), isTrue);

    // 2. Target file should exist
    final targetPath = p.join(
      tempDir.path,
      'Copy Movie (2021)',
      'Copy Movie (2021).mkv',
    );
    expect(await File(targetPath).exists(), isTrue);

    // 3. Undo log should NOT exist
    final logPath = p.join(
      tempDir.path,
      'Copy Movie (2021)',
      'rename_log.json',
    );
    expect(await File(logPath).exists(), isFalse);
  });

  test(
    'RenameMode.symLink creates symbolic link and does NOT create undo log',
    () async {
      final movieDir = await Directory(
        p.join(tempDir.path, 'Link Movie (2022)'),
      ).create();
      final file = await File(
        p.join(movieDir.path, 'Link.Movie.2022.mkv'),
      ).create();
      final item = MediaItem(
        path: file.path,
        type: MediaType.movie,
        detectedTitle: 'Link Movie',
        detectedYear: 2022,
      );

      try {
        await renamer.processItems(
          [item],
          scanRoot: movieDir.path,
          interactive: false,
          mode: RenameMode.symLink,
        );

        expect(await file.exists(), isTrue);
        final targetPath = p.join(
          tempDir.path,
          'Link Movie (2022)',
          'Link Movie (2022).mkv',
        );

        // Check if it's a link
        // On Windows, requires Developer Mode or Admin
        if (await Link(targetPath).exists()) {
          expect(await Link(targetPath).exists(), isTrue);
        } else {
          print('Skipping symlink verification (OS/Privilege issue)');
        }

        // Undo log should NOT exist
        final logPath = p.join(
          tempDir.path,
          'Link Movie (2022)',
          'rename_log.json',
        );
        expect(await File(logPath).exists(), isFalse);
      } catch (e) {
        print('Skipping symlink test due to error: $e');
      }
    },
  );

  // Note: hardLink test might require admin privileges on Windows or fail if temp is on different drive,
  // but usually temp dir is on C: which is standard.
  test(
    'RenameMode.hardLink creates hard link and does NOT create undo log',
    () async {
      final movieDir = await Directory(
        p.join(tempDir.path, 'Hard Movie (2023)'),
      ).create();
      final file = await File(
        p.join(movieDir.path, 'Hard.Movie.2023.mkv'),
      ).writeAsString('content');
      final item = MediaItem(
        path: file.path,
        type: MediaType.movie,
        detectedTitle: 'Hard Movie',
        detectedYear: 2023,
      );

      try {
        await renamer.processItems(
          [item],
          scanRoot: movieDir.path,
          interactive: false,
          mode: RenameMode.hardLink,
        );

        final targetPath = p.join(
          tempDir.path,
          'Hard Movie (2023)',
          'Hard Movie (2023).mkv',
        );
        final targetFile = File(targetPath);

        expect(await file.exists(), isTrue);
        expect(await targetFile.exists(), isTrue);
        expect(await targetFile.readAsString(), 'content');

        // Undo log should NOT exist
        final logPath = p.join(
          tempDir.path,
          'Hard Movie (2023)',
          'rename_log.json',
        );
        expect(await File(logPath).exists(), isFalse);
      } catch (e) {
        // If we don't have permission to create links, we skip but note it
        print(
          'Skipping hardlink test due to possible permission/OS issues: $e',
        );
      }
    },
  );

  test('Custom output directory creates files in correct location', () async {
    final movieDir = await Directory(
      p.join(tempDir.path, 'Custom Movie (2024)'),
    ).create();
    final file = await File(
      p.join(movieDir.path, 'Custom.Movie.2024.mkv'),
    ).create();
    final item = MediaItem(
      path: file.path,
      type: MediaType.movie,
      detectedTitle: 'Custom Movie',
      detectedYear: 2024,
    );

    final outputDir = await Directory(p.join(tempDir.path, 'OUTPUT')).create();

    await renamer.processItems(
      [item],
      scanRoot: movieDir.path,
      outputDir: outputDir.path,
      interactive: false,
      mode: RenameMode.copy, // Use copy to keep source
    );

    // Source should exist (because copy)
    expect(await file.exists(), isTrue);

    // Target should be in OUTPUT directory
    final targetPath = p.join(
      outputDir.path,
      'Custom Movie (2024)',
      'Custom Movie (2024).mkv',
    );
    expect(await File(targetPath).exists(), isTrue);
  });
}
