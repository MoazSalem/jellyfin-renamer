// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Movie _$MovieFromJson(Map<String, dynamic> json) => Movie(
  title: json['title'] as String,
  year: (json['year'] as num?)?.toInt(),
  imdbId: json['imdbId'] as String?,
  tmdbId: json['tmdbId'] as String?,
);

Map<String, dynamic> _$MovieToJson(Movie instance) => <String, dynamic>{
  'title': instance.title,
  'year': instance.year,
  'imdbId': instance.imdbId,
  'tmdbId': instance.tmdbId,
};

TvShow _$TvShowFromJson(Map<String, dynamic> json) => TvShow(
  title: json['title'] as String,
  seasons: (json['seasons'] as List<dynamic>)
      .map((e) => Season.fromJson(e as Map<String, dynamic>))
      .toList(),
  year: (json['year'] as num?)?.toInt(),
  tvdbId: json['tvdbId'] as String?,
  tmdbId: json['tmdbId'] as String?,
);

Map<String, dynamic> _$TvShowToJson(TvShow instance) => <String, dynamic>{
  'title': instance.title,
  'year': instance.year,
  'tvdbId': instance.tvdbId,
  'tmdbId': instance.tmdbId,
  'seasons': instance.seasons,
};

Season _$SeasonFromJson(Map<String, dynamic> json) => Season(
  number: (json['number'] as num).toInt(),
  episodes: (json['episodes'] as List<dynamic>)
      .map((e) => Episode.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$SeasonToJson(Season instance) => <String, dynamic>{
  'number': instance.number,
  'episodes': instance.episodes,
};

Episode _$EpisodeFromJson(Map<String, dynamic> json) => Episode(
  seasonNumber: (json['seasonNumber'] as num).toInt(),
  episodeNumberStart: json['episodeNumberStart'] as num,
  episodeNumberEnd: json['episodeNumberEnd'] as num?,
  title: json['title'] as String?,
);

Map<String, dynamic> _$EpisodeToJson(Episode instance) => <String, dynamic>{
  'seasonNumber': instance.seasonNumber,
  'episodeNumberStart': instance.episodeNumberStart,
  'episodeNumberEnd': instance.episodeNumberEnd,
  'title': instance.title,
};

RenameOperation _$RenameOperationFromJson(Map<String, dynamic> json) =>
    RenameOperation(
      originalPath: json['originalPath'] as String,
      newPath: json['newPath'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );

Map<String, dynamic> _$RenameOperationToJson(RenameOperation instance) =>
    <String, dynamic>{
      'originalPath': instance.originalPath,
      'newPath': instance.newPath,
      'timestamp': instance.timestamp.toIso8601String(),
    };
