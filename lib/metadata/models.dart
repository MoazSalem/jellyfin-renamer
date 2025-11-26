import 'package:json_annotation/json_annotation.dart';

part 'models.g.dart';

/// Enumeration of supported media types.
enum MediaType {
  /// Movie media type
  movie,

  /// TV show media type
  tvShow,

  /// Unknown or unsupported media type
  unknown,
}

/// Represents a media file with its metadata and associated subtitle files.
class MediaItem {
  /// Creates a new media item.
  ///
  /// [path] - File system path to the media file
  /// [type] - Type of media
  /// [detectedTitle] - Optional title detected from filename
  /// [detectedYear] - Optional year detected from filename
  /// [subtitlePaths] - Optional list of associated subtitle file paths
  /// [episode] - Optional episode information if the media is a TV show
  MediaItem({
    required this.path,
    required this.type,
    this.detectedTitle,
    this.detectedYear,
    List<String>? subtitlePaths,
    this.episode,
  }) : subtitlePaths = subtitlePaths ?? [];

  /// The file system path to the media file.
  final String path;

  /// The type of media (movie, TV show, or unknown).
  final MediaType type;

  /// The title detected from the filename, if any.
  final String? detectedTitle;

  /// The year detected from the filename, if any.
  final int? detectedYear;

  /// List of paths to subtitle files associated with this media file.
  final List<String> subtitlePaths;

  /// Episode information, if the media item is a TV show episode.
  final Episode? episode;

  /// Creates a copy of this [MediaItem] with the given fields replaced.
  MediaItem copyWith({
    String? path,
    MediaType? type,
    String? detectedTitle,
    int? detectedYear,
    List<String>? subtitlePaths,
    Episode? episode,
  }) {
    return MediaItem(
      path: path ?? this.path,
      type: type ?? this.type,
      detectedTitle: detectedTitle ?? this.detectedTitle,
      detectedYear: detectedYear ?? this.detectedYear,
      subtitlePaths: subtitlePaths ?? this.subtitlePaths,
      episode: episode ?? this.episode,
    );
  }
}

/// Result of a media scan operation.
class ScanResult {
  /// Creates a new scan result.
  ScanResult({
    required this.items,
    required this.unassociatedSubtitles,
  });

  /// List of detected media items.
  final List<MediaItem> items;

  /// List of subtitle files that were not associated with any video.
  final List<String> unassociatedSubtitles;
}

/// Represents a movie with its metadata.
@JsonSerializable()
class Movie {
  /// Creates a new movie instance.
  ///
  /// [title] - The movie title
  /// [year] - Optional release year
  /// [imdbId] - Optional IMDB identifier
  /// [tmdbId] - Optional TMDB identifier
  Movie({
    required this.title,
    this.year,
    this.imdbId,
    this.tmdbId,
  });

  /// Creates a Movie instance from a JSON map.
  factory Movie.fromJson(Map<String, dynamic> json) => _$MovieFromJson(json);

  /// The title of the movie.
  final String title;

  /// The release year of the movie, if known.
  final int? year;

  /// The IMDB ID of the movie, if available.
  final String? imdbId;

  /// The TMDB ID of the movie, if available.
  final String? tmdbId;

  /// Converts this movie to a JSON map.
  Map<String, dynamic> toJson() => _$MovieToJson(this);

  /// Returns the Jellyfin-compatible name for this movie.
  String get jellyfinName {
    final baseName = title
        .replaceAll(RegExp('[<>:"|?*]'), '')
        .replaceAll('/', '-');
    return year != null ? '$baseName ($year)' : baseName;
  }
}

/// Represents a TV show with its metadata and seasons.
@JsonSerializable()
class TvShow {
  /// Creates a new TV show instance.
  ///
  /// [title] - The TV show title
  /// [year] - Optional release year
  /// [tvdbId] - Optional TVDB identifier
  /// [tmdbId] - Optional TMDB identifier
  /// [seasons] - List of seasons in the show
  TvShow({
    required this.title,
    required this.seasons,
    this.year,
    this.tvdbId,
    this.tmdbId,
  });

  /// Creates a TvShow instance from a JSON map.
  factory TvShow.fromJson(Map<String, dynamic> json) => _$TvShowFromJson(json);

  /// The title of the TV show.
  final String title;

  /// The release year of the TV show, if known.
  final int? year;

  /// The TVDB ID of the TV show, if available.
  final String? tvdbId;

  /// The TMDB ID of the TV show, if available.
  final String? tmdbId;

  /// List of seasons in this TV show.
  final List<Season> seasons;

  /// Converts this TV show to a JSON map.
  Map<String, dynamic> toJson() => _$TvShowToJson(this);

  /// Returns the Jellyfin-compatible name for this TV show.
  String get jellyfinName {
    final baseName = title
        .replaceAll(RegExp('[<>:"|?*]'), '')
        .replaceAll('/', '-');
    return year != null ? '$baseName ($year)' : baseName;
  }
}

/// Represents a season of a TV show.
@JsonSerializable()
class Season {
  /// Creates a new season instance.
  ///
  /// [number] - The season number
  /// [episodes] - List of episodes in this season
  Season({
    required this.number,
    required this.episodes,
  });

  /// Creates a Season instance from a JSON map.
  factory Season.fromJson(Map<String, dynamic> json) => _$SeasonFromJson(json);

  /// The season number.
  final int number;

  /// List of episodes in this season.
  final List<Episode> episodes;

  /// Converts this season to a JSON map.
  Map<String, dynamic> toJson() => _$SeasonToJson(this);
}

/// Represents an episode of a TV show.
@JsonSerializable()
class Episode {
  /// Creates a new episode instance.
  ///
  /// [seasonNumber] - The season number
  /// [episodeNumberStart] - The starting episode number
  /// [episodeNumberEnd] - The ending episode number, for multi-episode files
  /// [title] - Optional episode title
  Episode({
    required this.seasonNumber,
    required this.episodeNumberStart,
    this.episodeNumberEnd,
    this.title,
  });

  /// Creates an Episode instance from a JSON map.
  factory Episode.fromJson(Map<String, dynamic> json) =>
      _$EpisodeFromJson(json);

  /// The season number this episode belongs to.
  final int seasonNumber;

  /// The starting episode number within the season.
  final num episodeNumberStart;

  /// The ending episode number for multi-episode files.
  final num? episodeNumberEnd;

  /// The title of the episode, if known.
  final String? title;

  /// Converts this episode to a JSON map.
  Map<String, dynamic> toJson() => _$EpisodeToJson(this);

  /// Returns the episode code in SxxExx format
  /// (e.g., "S01E05" or "S01E05-E06").
  String get episodeCode {
    final seasonStr = 'S${seasonNumber.toString().padLeft(2, '0')}';
    
    String formatNum(num n) {
      // If integer, pad with 0. If double, keep as is (e.g. 6.5)
      // Ideally we want 06.5 for sorting?
      // Let's stick to simple padding for integer part.
      if (n is int || n == n.roundToDouble()) {
        return n.toInt().toString().padLeft(2, '0');
      }
      // For fractional, pad the integer part: 6.5 -> 06.5
      final intPart = n.floor();
      final fracPart = n - intPart;
      // Remove "0." from fraction string "0.5" -> ".5"
      final fracStr = fracPart.toString().substring(1); 
      return '${intPart.toString().padLeft(2, '0')}$fracStr';
    }

    final episodeStartStr = 'E${formatNum(episodeNumberStart)}';
    if (episodeNumberEnd != null) {
      final episodeEndStr = 'E${formatNum(episodeNumberEnd!)}';
      return '$seasonStr$episodeStartStr-$episodeEndStr';
    }
    return '$seasonStr$episodeStartStr';
  }
}

/// Represents a rename operation with timestamp for undo functionality.
@JsonSerializable()
class RenameOperation {
  /// Creates a new rename operation.
  ///
  /// [originalPath] - The original file path
  /// [newPath] - The new file path
  /// [timestamp] - When the operation occurred
  RenameOperation({
    required this.originalPath,
    required this.newPath,
    required this.timestamp,
  });

  /// Creates a RenameOperation instance from a JSON map.
  factory RenameOperation.fromJson(Map<String, dynamic> json) =>
      _$RenameOperationFromJson(json);

  /// The original file path before renaming.
  final String originalPath;

  /// The new file path after renaming.
  final String newPath;

  /// The timestamp when the rename operation occurred.
  final DateTime timestamp;

  /// Converts this rename operation to a JSON map.
  Map<String, dynamic> toJson() => _$RenameOperationToJson(this);
}
