/// The handful of email domains people overwhelmingly use — good enough to
/// catch the common one-character slip (e.g. "gmai.com") without needing a
/// full public-suffix list.
const List<String> _commonEmailDomains = [
  'gmail.com',
  'hotmail.com',
  'outlook.com',
  'yahoo.com',
  'live.com',
  'icloud.com',
  'me.com',
  'msn.com',
];

/// If [email]'s domain looks like a near-miss typo of a common domain (edit
/// distance 1-2, but not an exact match), returns the corrected email.
/// Otherwise returns null — including when the domain is already fine, or
/// isn't close enough to any common domain to guess confidently.
String? suggestEmailCorrection(String email) {
  final at = email.lastIndexOf('@');
  if (at == -1 || at == email.length - 1) return null;

  final domain = email.substring(at + 1).toLowerCase();
  if (_commonEmailDomains.contains(domain)) return null;

  String? closest;
  var bestDistance = 3; // only ever suggest a genuinely close typo
  for (final candidate in _commonEmailDomains) {
    final distance = _levenshteinDistance(domain, candidate);
    if (distance > 0 && distance < bestDistance) {
      bestDistance = distance;
      closest = candidate;
    }
  }
  if (closest == null) return null;

  return '${email.substring(0, at + 1)}$closest';
}

int _levenshteinDistance(String a, String b) {
  final rows = a.length + 1;
  final cols = b.length + 1;
  final distances = List.generate(rows, (i) => List.filled(cols, 0));

  for (var i = 0; i < rows; i++) {
    distances[i][0] = i;
  }
  for (var j = 0; j < cols; j++) {
    distances[0][j] = j;
  }

  for (var i = 1; i < rows; i++) {
    for (var j = 1; j < cols; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      distances[i][j] = [
        distances[i - 1][j] + 1,
        distances[i][j - 1] + 1,
        distances[i - 1][j - 1] + cost,
      ].reduce((min, value) => value < min ? value : min);
    }
  }

  return distances[rows - 1][cols - 1];
}
