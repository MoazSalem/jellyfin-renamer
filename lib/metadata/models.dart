import 'package:json_annotation/json_annotation.dart';

part 'models.g.dart';

enum MediaType { movie, tvShow, unknown }

class MediaItem {
  final String path;
  final MediaType type;
  final String? detectedTitle;
  final int? detectedYear;
  final List<String> subtitlePaths;

  MediaItem({
    required this.path,
    required this.type,
    this.detectedTitle,
    this.detectedYear,
    List<String>? subtitlePaths,
  }) : subtitlePaths = subtitlePaths ?? [];
}

@JsonSerializable()
class Movie {
  final String title;
  final int? year;
  final String? imdbId;
  final String? tmdbId;

  Movie({
    required this.title,
    this.year,
    this.imdbId,
    this.tmdbId,
  });

  factory Movie.fromJson(Map<String, dynamic> json) => _$MovieFromJson(json);
  Map<String, dynamic> toJson() => _$MovieToJson(this);

  String get jellyfinName {
    final baseName = title.replaceAll(RegExp(r'[<>:"|?*]'), '').replaceAll('/', '-');
    return year != null ? '$baseName ($year)' : baseName;
  }
}

@JsonSerializable()
class TvShow {
  final String title;
  final int? year;
  final String? tvdbId;
  final String? tmdbId;
  final List<Season> seasons;

  TvShow({
    required this.title,
    this.year,
    this.tvdbId,
    this.tmdbId,
    required this.seasons,
  });

  factory TvShow.fromJson(Map<String, dynamic> json) => _$TvShowFromJson(json);
  Map<String, dynamic> toJson() => _$TvShowToJson(this);

  String get jellyfinName {
    final baseName = title.replaceAll(RegExp(r'[<>:"|?*]'), '').replaceAll('/', '-');
    return year != null ? '$baseName ($year)' : baseName;
  }
}

@JsonSerializable()
class Season {
  final int number;
  final List<Episode> episodes;

  Season({
    required this.number,
    required this.episodes,
  });

  factory Season.fromJson(Map<String, dynamic> json) => _$SeasonFromJson(json);
  Map<String, dynamic> toJson() => _$SeasonToJson(this);
}

@JsonSerializable()
class Episode {
  final int seasonNumber;
  final int episodeNumber;
  final String? title;

  Episode({
    required this.seasonNumber,
    required this.episodeNumber,
    this.title,
  });

  factory Episode.fromJson(Map<String, dynamic> json) => _$EpisodeFromJson(json);
  Map<String, dynamic> toJson() => _$EpisodeToJson(this);

  String get episodeCode => 'S${seasonNumber.toString().padLeft(2, '0')}E${episodeNumber.toString().padLeft(2, '0')}';
}

@JsonSerializable()
class RenameOperation {
  final String originalPath;
  final String newPath;
  final DateTime timestamp;

  RenameOperation({
    required this.originalPath,
    required this.newPath,
    required this.timestamp,
  });

  factory RenameOperation.fromJson(Map<String, dynamic> json) => _$RenameOperationFromJson(json);
  Map<String, dynamic> toJson() => _$RenameOperationToJson(this);
}