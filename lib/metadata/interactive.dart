import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:renamer/metadata/models.dart';
import 'package:renamer/utils/title_processor.dart';

/// Handles interactive user prompts for media metadata input.
class InteractivePrompt {
  final Stdin _stdin = stdin;
  final Stdout _stdout = stdout;

  /// Prompts user to select or enter movie details interactively.
  ///
  /// [suggestions] - List of movie suggestions to present to the user
  /// Returns the selected movie or null if user chooses to skip.
  Future<Movie?> promptMovieDetails(List<Movie> suggestions) async {
    if (suggestions.isEmpty) {
      return _promptManualMovieEntry();
    }

    _stdout.writeln('Found movie matches:');
    for (var i = 0; i < suggestions.length; i++) {
      _stdout.writeln('${i + 1}. ${suggestions[i].jellyfinName}');
    }
    _stdout
      ..writeln('${suggestions.length + 1}. Enter manually')
      ..writeln('${suggestions.length + 2}. Skip this file')
      ..write('Select option: ');

    final input = _readLine().trim();
    final choice = int.tryParse(input);

    if (choice != null && choice > 0 && choice <= suggestions.length) {
      return suggestions[choice - 1];
    } else if (choice == suggestions.length + 1) {
      return _promptManualMovieEntry();
    } else if (choice == suggestions.length + 2) {
      return null; // Skip
    }

    _stdout.writeln('Invalid choice, skipping...');
    return null;
  }

  Future<Movie> _promptManualMovieEntry() async {
    _stdout.write('Enter movie title: ');
    final title = _readLine().trim();

    if (title.isEmpty) {
      throw Exception('Title cannot be empty');
    }

    _stdout.write('Enter year (optional): ');
    final yearInput = _readLine().trim();
    final year = yearInput.isNotEmpty ? int.tryParse(yearInput) : null;

    _stdout.write('Enter IMDB ID (optional): ');
    final imdbId = _readLine().trim();
    final imdb = imdbId.isNotEmpty ? imdbId : null;

    return Movie(
      title: title,
      year: year,
      imdbId: imdb,
    );
  }

  /// Prompts user to select a TV show from detected candidates.
  ///
  /// [showCandidates] - List of detected show name candidates
  /// [files] - List of media files to be processed
  /// Returns the selected TV show or null if user chooses to skip.
  Future<TvShow?> promptShowSelectionWithFiles(
    List<({String? title, int? year})> showCandidates,
    List<MediaItem> files,
  ) async {
    _stdout.writeln(
      '\n📺 Found ${files.length} episode files:',
    );

    for (final file in files) {
      final fileName = path.basename(file.path);
      final episode = _extractEpisodeInfo(file.path);
      if (episode != null) {
        _stdout.writeln(
          '  • $fileName → Season ${episode.seasonNumber}, '
          'Episode ${episode.episodeNumber}',
        );
      } else {
        _stdout.writeln('  • $fileName → Could not parse episode info');
      }
    }

    _stdout.writeln('\nDetected show name options:');
    final validCandidates = showCandidates
        .where((c) => c.title != null)
        .toSet()
        .toList();
    for (var i = 0; i < validCandidates.length; i++) {
      final candidate = validCandidates[i];
      final displayName = candidate.year != null
          ? '${candidate.title} (${candidate.year})'
          : candidate.title;
      _stdout.writeln('${i + 1}. $displayName');
    }
    _stdout
      ..writeln('${validCandidates.length + 1}. Enter different show name')
      ..writeln('${validCandidates.length + 2}. Skip these files')
      ..write('Select option: ');

    final input = _readLine().trim();
    final choice = int.tryParse(input);

    if (choice != null && choice > 0 && choice <= validCandidates.length) {
      final selected = validCandidates[choice - 1];
      return TvShow(title: selected.title!, year: selected.year, seasons: []);
    } else if (choice == validCandidates.length + 1) {
      return _promptManualShowEntry();
    } else if (choice == validCandidates.length + 2) {
      return null;
    }

    _stdout.writeln('Invalid choice, skipping...');
    return null;
  }

  Episode? _extractEpisodeInfo(String filePath) {
    final fileName = path.basenameWithoutExtension(filePath);
    final episodeMatch = RegExp(
      r'S(\d{1,2})E(\d{1,2})',
      caseSensitive: false,
    ).firstMatch(fileName);
    if (episodeMatch != null) {
      final seasonNum = int.parse(episodeMatch.group(1)!);
      final episodeNum = int.parse(episodeMatch.group(2)!);
      return Episode(seasonNumber: seasonNum, episodeNumber: episodeNum);
    }
    return null;
  }

  Future<TvShow> _promptManualShowEntry() async {
    _stdout.write('Enter TV show title: ');
    final title = _readLine().trim();

    if (title.isEmpty) {
      throw Exception('Title cannot be empty');
    }

    _stdout.write('Enter year (optional): ');
    final yearInput = _readLine().trim();
    final year = yearInput.isNotEmpty ? int.tryParse(yearInput) : null;

    return TvShow(
      title: title,
      year: year,
      seasons: [], // Will be populated from files
    );
  }

  /// Prompts user to enter a custom folder name for TV shows.
  ///
  /// Returns the user-specified folder name for organizing TV shows.
  Future<String> promptTvFolderName() async {
    _stdout
      ..writeln('\n📁 TV Shows Folder Configuration')
      ..writeln(
        'Jellyfin typically organizes TV shows under a "TV Shows" folder.',
      )
      ..writeln(
        'You can customize this folder name or '
        'leave it empty to skip the folder.',
      )
      ..write(
        'Enter TV shows folder name (default: "TV Shows", empty to skip): ',
      );

    final input = _readLine().trim();
    if (input.isEmpty) {
      return ''; // Skip the folder
    }
    return input;
  }

  /// Prompts user to choose a title extraction method when the detected title
  /// doesn't look correct.
  ///
  /// [fileName] - The original filename to extract title from
  /// [currentTitle] - The currently detected title
  /// Returns the selected title and year, or null if user chooses to skip.
  Future<({String? title, int? year})?> promptTitleExtraction(
    String fileName,
    String? currentTitle,
  ) async {
    _stdout
      ..writeln('\n📝 Title Detection Options')
      ..writeln('Filename: $fileName')
      ..writeln('Current detected title: "${currentTitle ?? 'None'}"');

    // Automatically extract title using keyword method
    final extractedResult = TitleProcessor.extractTitleUntilKeywords(fileName);
    final extractedTitle = extractedResult.title;

    _stdout
      ..writeln()
      ..writeln('Choose title to use:')
      ..writeln('1. Use current detected title');

    if (extractedTitle != null && extractedTitle != currentTitle) {
      _stdout.writeln('2. Use extracted title: "$extractedTitle"');
    }

    final manualOption =
        extractedTitle != null && extractedTitle != currentTitle ? 3 : 2;
    final skipOption = extractedTitle != null && extractedTitle != currentTitle
        ? 4
        : 3;

    _stdout
      ..writeln('$manualOption. Enter title manually')
      ..writeln('$skipOption. Skip this file')
      ..write('Select option (1-$skipOption): ');

    final input = _readLine().trim();
    final choice = int.tryParse(input);

    if (choice == 1) {
      // Extract year from current title if present
      final yearMatch = RegExp(
        r'\b(19|20)\d{2}\b',
      ).firstMatch(currentTitle ?? '');
      final year = yearMatch != null ? int.tryParse(yearMatch.group(0)!) : null;
      return (title: currentTitle, year: year);
    } else if (extractedTitle != null &&
        extractedTitle != currentTitle &&
        choice == 2) {
      return extractedResult;
    } else if (choice == manualOption) {
      // Manual entry
      _stdout.write('Enter title: ');
      final title = _readLine().trim();
      if (title.isEmpty) {
        _stdout.writeln('Title cannot be empty.');
        return null;
      }

      _stdout.write('Enter year (optional): ');
      final yearInput = _readLine().trim();
      final year = yearInput.isNotEmpty ? int.tryParse(yearInput) : null;

      return (title: title, year: year);
    } else if (choice == skipOption) {
      return null; // Skip
    } else {
      _stdout.writeln('Invalid choice.');
      return null;
    }
  }

  /// Prompts user to confirm if a group of directories belong to the same show.
  ///
  /// [showNameGuess] - The guessed show name for the group.
  /// [directoryGroups] - The list of directory paths grouped
  /// under the show name.
  /// Returns true if the user confirms, false otherwise.
  Future<bool> confirmGroup(
    String showNameGuess,
    List<List<MediaItem>> directoryGroups,
  ) async {
    _stdout
      ..writeln(
        "\n🤔 I've found ${directoryGroups.length} directories that seem to"
        ' belong to the same show: "$showNameGuess".',
      )
      ..writeln('Directories found:');
    for (final group in directoryGroups) {
      final dirPath = path.dirname(group.first.path);
      _stdout.writeln('  - $dirPath');
    }
    _stdout.write('Are these directories for the same show? (y/n): ');
    final input = _readLine().trim().toLowerCase();
    return input == 'y' || input == 'yes';
  }

  /// Prompts user to confirm execution of the planned operations.
  ///
  /// Returns true if the user confirms, false otherwise.
  Future<bool> confirmExecution() async {
    _stdout.write('\nProceed with the above operations? (y/n): ');
    final input = _readLine().trim().toLowerCase();
    return input == 'y' || input == 'yes';
  }

  String _readLine() {
    return _stdin.readLineSync() ?? '';
  }
}
