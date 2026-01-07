/// Utility class for sorting and comparing strings.
class SortUtils {
  /// Compares two strings using natural sort order.
  ///
  /// Splits strings into text and numeric segments and compares them.
  /// E.g. "File 2" < "File 10"
  static int naturalCompare(String a, String b) {
    // Split into groups of non-digits and digits
    final pattern = RegExp(r'(\d+|\D+)');
    final aMatches = pattern.allMatches(a).map((m) => m.group(0)!).toList();
    final bMatches = pattern.allMatches(b).map((m) => m.group(0)!).toList();

    for (var i = 0; i < aMatches.length && i < bMatches.length; i++) {
      final aPart = aMatches[i];
      final bPart = bMatches[i];

      final aIsNum = int.tryParse(aPart) != null;
      final bIsNum = int.tryParse(bPart) != null;

      if (aIsNum && bIsNum) {
        final comparison = int.parse(aPart).compareTo(int.parse(bPart));
        if (comparison != 0) return comparison;
      } else {
        final comparison = aPart.compareTo(bPart);
        if (comparison != 0) return comparison;
      }
    }

    return aMatches.length.compareTo(bMatches.length);
  }
}
