/// Client-side accent-aware text matching, mirroring the backend `TextSearch.WhereContains`
/// semantics for the few searches that filter an already-loaded list (e.g. the organizer
/// statistics per-tour search) rather than hitting the API. A plain term is accent-insensitive
/// ("Poc" matches "Počitelj"); a term that itself carries diacritics stays accent-sensitive.
library;

// Lowercased accented Latin letters → their base letter. Covers Bosnian (č ć š ž đ) plus the
// common European diacritics, so folding is robust for the seeded and user-entered data.
const Map<String, String> _foldMap = {
  'à': 'a',
  'á': 'a',
  'â': 'a',
  'ã': 'a',
  'ä': 'a',
  'å': 'a',
  'ā': 'a',
  'ă': 'a',
  'ą': 'a',
  'ç': 'c',
  'č': 'c',
  'ć': 'c',
  'ĉ': 'c',
  'ċ': 'c',
  'đ': 'd',
  'ď': 'd',
  'è': 'e',
  'é': 'e',
  'ê': 'e',
  'ë': 'e',
  'ē': 'e',
  'ĕ': 'e',
  'ė': 'e',
  'ę': 'e',
  'ě': 'e',
  'ĝ': 'g',
  'ğ': 'g',
  'ġ': 'g',
  'ģ': 'g',
  'ì': 'i',
  'í': 'i',
  'î': 'i',
  'ï': 'i',
  'ĩ': 'i',
  'ī': 'i',
  'ĭ': 'i',
  'į': 'i',
  'ĺ': 'l',
  'ļ': 'l',
  'ľ': 'l',
  'ł': 'l',
  'ñ': 'n',
  'ń': 'n',
  'ņ': 'n',
  'ň': 'n',
  'ò': 'o',
  'ó': 'o',
  'ô': 'o',
  'õ': 'o',
  'ö': 'o',
  'ō': 'o',
  'ŏ': 'o',
  'ő': 'o',
  'ø': 'o',
  'ŕ': 'r',
  'ř': 'r',
  'ś': 's',
  'ŝ': 's',
  'ş': 's',
  'š': 's',
  'ţ': 't',
  'ť': 't',
  'ù': 'u',
  'ú': 'u',
  'û': 'u',
  'ü': 'u',
  'ũ': 'u',
  'ū': 'u',
  'ŭ': 'u',
  'ů': 'u',
  'ű': 'u',
  'ų': 'u',
  'ý': 'y',
  'ÿ': 'y',
  'ź': 'z',
  'ż': 'z',
  'ž': 'z',
};

/// Lower-cases [input] and strips diacritics to their base letters.
String foldDiacritics(String input) {
  final lower = input.toLowerCase();
  final buffer = StringBuffer();
  for (final char in lower.split('')) {
    buffer.write(_foldMap[char] ?? char);
  }
  return buffer.toString();
}

/// Whether [input] contains any diacritics (relative to its own case-folded form).
bool hasDiacritics(String input) =>
    foldDiacritics(input) != input.toLowerCase();

/// True when [haystack] contains [needle], with the same accent-awareness as the backend:
/// a plain [needle] matches accent-insensitively; an accented [needle] matches accent-sensitively.
/// A blank [needle] matches everything.
bool accentAwareContains(String haystack, String needle) {
  final term = needle.trim();
  if (term.isEmpty) return true;
  if (hasDiacritics(term)) {
    return haystack.toLowerCase().contains(term.toLowerCase());
  }
  return foldDiacritics(haystack).contains(foldDiacritics(term));
}
