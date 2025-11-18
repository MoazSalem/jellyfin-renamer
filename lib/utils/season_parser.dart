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
};

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
};

int? extractSeasonFromDirName(String dirName) {
  final lowerDirName = dirName.toLowerCase();

  final seasonMatch = RegExp(
    r'^(?:season\s*|s)(\d+)$',
    caseSensitive: false,
  ).firstMatch(lowerDirName);
  if (seasonMatch != null) {
    return int.tryParse(seasonMatch.group(1)!);
  }

  for (final entry in wordToNumber.entries) {
    if (lowerDirName == 'season ${entry.key}') {
      return entry.value;
    }
  }

  for (final entry in ordinalToNumber.entries) {
    if (lowerDirName == '${entry.key} season') {
      return entry.value;
    }
  }

  return null;
}
