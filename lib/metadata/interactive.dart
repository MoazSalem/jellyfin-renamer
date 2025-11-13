import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:renamer/metadata/models.dart';

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
    List<({String title, int? year})> showCandidates,
    List<MediaItem> files,
  ) async {
    _stdout.writeln(
      '\n📺 Found ${files.length} episode files in directory: '
      '${path.dirname(files.first.path)}',
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
    for (var i = 0; i < showCandidates.length; i++) {
      final candidate = showCandidates[i];
      final displayName = candidate.year != null
          ? '${candidate.title} (${candidate.year})'
          : candidate.title;
      _stdout.writeln('${i + 1}. $displayName');
    }
    _stdout
      ..writeln('${showCandidates.length + 1}. Enter different show name')
      ..writeln('${showCandidates.length + 2}. Skip these files')
      ..write('Select option: ');

    final input = _readLine().trim();
    final choice = int.tryParse(input);

    if (choice != null && choice > 0 && choice <= showCandidates.length) {
      final selected = showCandidates[choice - 1];
      return TvShow(title: selected.title, year: selected.year, seasons: []);
    } else if (choice == showCandidates.length + 1) {
      return _promptManualShowEntry();
    } else if (choice == showCandidates.length + 2) {
      return null;
    }

    _stdout.writeln('Invalid choice, skipping...');
    return null;
  }

  /// Prompts user to confirm or modify TV show details with file information.
  ///
  /// [detectedShow] - The automatically detected TV show
  /// [files] - List of media files for context
  /// [fullName] - Optional full directory name for display
  /// Returns the confirmed TV show or null if user chooses to skip.
  Future<TvShow?> promptTvShowDetailsWithFiles(
    TvShow detectedShow,
    List<MediaItem> files, {
    String? fullName,
  }) async {
    _stdout
      ..writeln('\n📺 Detected TV Show: ${detectedShow.title}')
      ..writeln('Found ${files.length} episode files:');

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

    _stdout
      ..writeln('\nOptions:')
      ..writeln(
        '1. Use detected show name: "${detectedShow.jellyfinName}"',
      );
    if (fullName != null && fullName != detectedShow.title) {
      _stdout
        ..writeln('2. Use full directory name: "$fullName"')
        ..writeln('3. Enter different show name')
        ..writeln('4. Skip these files')
        ..write('Select option (1-4): ');

      final input = _readLine().trim();
      switch (input) {
        case '1':
          return detectedShow;
        case '2':
          return TvShow(
            title: fullName,
            year: detectedShow.year,
            seasons: detectedShow.seasons,
          );
        case '3':
          return _promptManualTvShowEntryWithEpisodes(
            detectedShow.seasons,
          );
        case '4':
          return null;
        default:
          _stdout.writeln('Invalid choice, skipping...');
          return null;
      }
    } else {
      _stdout
        ..writeln('2. Enter different show name')
        ..writeln('3. Skip these files')
        ..write('Select option (1-3): ');

      final input = _readLine().trim();
      switch (input) {
        case '1':
          return detectedShow;
        case '2':
          return _promptManualTvShowEntryWithEpisodes(
            detectedShow.seasons,
          );
        case '3':
          return null;
        default:
          _stdout.writeln('Invalid choice, skipping...');
          return null;
      }
    }
  }

  /// Prompts user to select from TV show suggestions.
  ///
  /// [suggestions] - List of TV show suggestions to present to the user
  /// Returns the selected TV show or null if user chooses to skip.
  Future<TvShow?> promptTvShowDetails(List<TvShow> suggestions) async {
    if (suggestions.isEmpty) {
      return _promptManualTvShowEntry();
    }

    _stdout.writeln('Found TV show matches:');
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
      return _promptManualTvShowEntry();
    } else if (choice == suggestions.length + 2) {
      return null; // Skip
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

  Future<TvShow> _promptManualTvShowEntryWithEpisodes(
    List<Season> detectedSeasons,
  ) async {
    _stdout.write('Enter TV show title: ');
    final title = _readLine().trim();

    if (title.isEmpty) {
      throw Exception('Title cannot be empty');
    }

    _stdout.write('Enter year (optional): ');
    final yearInput = _readLine().trim();
    final year = yearInput.isNotEmpty ? int.tryParse(yearInput) : null;

    // Use the detected seasons but allow user to modify
    _stdout.writeln('Detected seasons and episodes:');
    for (final season in detectedSeasons) {
      _stdout.writeln(
        '  Season ${season.number}: ${season.episodes.length} episodes',
      );
    }

    _stdout.write('Use detected season/episode info? (y/n): ');
    final useDetected = _readLine().trim().toLowerCase() == 'y';

    if (!useDetected) {
      _stdout.write('Enter season number: ');
      final seasonInput = _readLine().trim();
      final seasonNum = int.tryParse(seasonInput) ?? 1;

      _stdout.write('Enter episode number: ');
      final episodeInput = _readLine().trim();
      final episodeNum = int.tryParse(episodeInput) ?? 1;

      final episode = Episode(
        seasonNumber: seasonNum,
        episodeNumber: episodeNum,
      );
      final season = Season(number: seasonNum, episodes: [episode]);

      return TvShow(
        title: title,
        year: year,
        seasons: [season],
      );
    }

    return TvShow(
      title: title,
      year: year,
      seasons: detectedSeasons,
    );
  }

  Future<TvShow> _promptManualTvShowEntry() async {
    _stdout.write('Enter TV show title: ');
    final title = _readLine().trim();

    if (title.isEmpty) {
      throw Exception('Title cannot be empty');
    }

    _stdout.write('Enter year (optional): ');
    final yearInput = _readLine().trim();
    final year = yearInput.isNotEmpty ? int.tryParse(yearInput) : null;

    _stdout.write('Enter season number: ');
    final seasonInput = _readLine().trim();
    final seasonNum = int.tryParse(seasonInput) ?? 1;

    _stdout.write('Enter episode number: ');
    final episodeInput = _readLine().trim();
    final episodeNum = int.tryParse(episodeInput) ?? 1;

    final episode = Episode(seasonNumber: seasonNum, episodeNumber: episodeNum);
    final season = Season(number: seasonNum, episodes: [episode]);

    return TvShow(
      title: title,
      year: year,
      seasons: [season],
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
