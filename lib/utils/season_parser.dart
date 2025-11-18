/// Mapping of cardinal number words to their numeric values.
///
/// Supports both English and Arabic number words
/// (e.g., 'one' -> 1, 'واحد' -> 1).
/// Used for parsing season names like "Season One" or "الموسم واحد".
const wordToNumber = {
  'one': 1,
  'two': 2,
  'three': 3,
  'four': 4,
  'five': 5,
  'six': 6,
  'seven': 7,
  'eight': 8,
  'nine': 9,
  'ten': 10,
  'eleven': 11,
  'twelve': 12,
  'thirteen': 13,
  'fourteen': 14,
  'fifteen': 15,
  'sixteen': 16,
  'seventeen': 17,
  'eighteen': 18,
  'nineteen': 19,
  'twenty': 20,
  'واحد': 1,
  'اثنان': 2,
  'ثلاثة': 3,
  'أربعة': 4,
  'خمسة': 5,
  'ستة': 6,
  'سبعة': 7,
  'ثمانية': 8,
  'تسعة': 9,
  'عشرة': 10,
  'أحد عشر': 11,
  'اثنى عشر': 12,
  'اثنا عشر': 12,
  'ثلاثة عشر': 13,
  'أربعة عشر': 14,
  'خمسة عشر': 15,
  'ستة عشر': 16,
  'سبعة عشر': 17,
  'ثمانية عشر': 18,
  'تسعة عشر': 19,
  'عشرون': 20,
  'عشرين': 20,
};

/// Mapping of ordinal number words to their numeric values.
///
/// Supports both English and Arabic ordinal words
/// (e.g., 'first' -> 1, 'الأول' -> 1).
/// Used for parsing season names like "First Season" or "الموسم الأول".
const ordinalToNumber = {
  'first': 1,
  'second': 2,
  'third': 3,
  'fourth': 4,
  'fifth': 5,
  'sixth': 6,
  'seventh': 7,
  'eighth': 8,
  'ninth': 9,
  'tenth': 10,
  'eleventh': 11,
  'twelfth': 12,
  'thirteenth': 13,
  'fourteenth': 14,
  'fifteenth': 15,
  'sixteenth': 16,
  'seventeenth': 17,
  'eighteenth': 18,
  'nineteenth': 19,
  'twentieth': 20,
  'الأول': 1,
  'الاول': 1,
  'الاولى': 1,
  'الأولى': 1,
  'الثاني': 2,
  'الثانى': 2,
  'الثانىة': 2,
  'الثالث': 3,
  'الثالثة': 3,
  'الرابع': 4,
  'الرابعة': 4,
  'الخامس': 5,
  'الخامسة': 5,
  'السادس': 6,
  'السادسة': 6,
  'السابع': 7,
  'السابعة': 7,
  'الثامن': 8,
  'الثامنة': 8,
  'التاسع': 9,
  'التاسعة': 9,
  'العاشر': 10,
  'العاشرة': 10,
  'الحادي عشر': 11,
  'الحادى عشر': 11,
  'الحادية عشر': 11,
  'الثاني عشر': 12,
  'الثانى عشر': 12,
  'الثانية عشر': 12,
  'الثالث عشر': 13,
  'الثالثة عشر': 13,
  'الرابع عشر': 14,
  'الرابعة عشر': 14,
  'الخامس عشر': 15,
  'الخامسة عشر': 15,
  'السادس عشر': 16,
  'الستة عشر': 16,
  'السادسة عشر': 16,
  'السابع عشر': 17,
  'السبعة عشر': 17,
  'السابعة عشر': 17,
  'الثامن عشر': 18,
  'الثمانية عشر': 18,
  'التاسع عشر': 19,
  'التسعة عشر': 19,
  'التاسعة عشر': 19,
  'العشرون': 20,
  'العشرين': 20,
};

/// Extracts the season number from a directory name.
///
/// Supports multiple formats:
/// - Numeric: "Season 1", "S01", "الموسم 1"
/// - Word-based: "Season One", "الموسم واحد"
/// - Ordinal: "First Season", "الموسم الأول"
///
/// Returns the season number if found, or null if the directory name
/// doesn't match any known season pattern.
///
/// Example:
/// ```dart
/// extractSeasonFromDirName('Season 1'); // Returns 1
/// extractSeasonFromDirName('Season One'); // Returns 1
/// extractSeasonFromDirName('Random Folder'); // Returns null
/// ```
int? extractSeasonFromDirName(String dirName) {
  final lowerDirName = dirName.toLowerCase();

  final seasonMatch = RegExp(
    r'^(?:season\s*|s|الموسم\s*)(\d+)$',
    caseSensitive: false,
  ).firstMatch(lowerDirName);
  if (seasonMatch != null) {
    return int.tryParse(seasonMatch.group(1)!);
  }

  for (final entry in wordToNumber.entries) {
    if (lowerDirName == 'season ${entry.key.toLowerCase()}' ||
        lowerDirName == 'الموسم ${entry.key.toLowerCase()}') {
      return entry.value;
    }
  }

  for (final entry in ordinalToNumber.entries) {
    if (lowerDirName == '${entry.key.toLowerCase()} season' ||
        lowerDirName == 'الموسم ${entry.key.toLowerCase()}') {
      return entry.value;
    }
  }

  return null;
}
