/// File extensions supported by the media scanner.
class FileExtensions {
  /// Supported video file extensions.
  static const List<String> video = [
    '.mkv',
    '.mp4',
    '.avi',
    '.mov',
    '.m4v',
    '.wmv',
  ];

  /// Supported subtitle file extensions.
  static const List<String> subtitle = [
    '.srt',
    '.sub',
    '.ass',
    '.ssa',
    '.vtt',
  ];
}

/// Words and tags that should be filtered out when processing media filenames.
/// This includes release tags, quality indicators, and other metadata that
/// should be removed when extracting clean titles.
const List<String> filenameFilterWords = [
  // Release tags
  'complete',
  '720p',
  '1080p',
  '2160p',
  '4k',
  'webrip',
  'bluray',
  'bdrip',
  'dvdrip',
  'hdtv',
  'x265',
  'x264',
  'hevc',
  'h264',
  'aac',
  'ac3',
  'dts',
  'flac',
  'mp3',
  '2ch',
  '5.1',
  '7.1',
  '10bit',
  '8bit',
  'psa',
  'heteam',
  'etrg',
  'sparks',
  'rarbg',
  'yify',
  'amzn',
  'nf',
  'hbo',
  'bbc',
  'discovery',

  // Subtitle filter words
  'web',
  'rip',
  'bit',
  'joy',
  'heb',
  'team',
  'h264',
  'h265',
  'avc',
  'hdr',
  'netflix',
  'amazon',
  'disney',
  'max',
  'cr',
  'proper',
  'repack',
  'internal',
  'limited',
  'series',
  'season',
];
