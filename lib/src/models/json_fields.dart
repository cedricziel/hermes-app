/// Reads [key] as a [T], or [fallback] when it is absent or null. A value of
/// another type throws [FormatException] rather than a `TypeError`.
T jsonField<T>(Map<String, dynamic> json, String key, T fallback) {
  final value = json[key];
  if (value == null) return fallback;
  if (value is! T) throw FormatException('malformed "$key" field');
  return value;
}

/// Like [jsonField] for an optional value, with null as the fallback.
T? jsonFieldOrNull<T>(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! T) throw FormatException('malformed "$key" field');
  return value;
}

/// Reads [key] as a list, stringifying its elements; absent means empty.
List<String> jsonStringList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return const [];
  if (value is! List) throw FormatException('malformed "$key" field');
  return value.map((e) => e.toString()).toList();
}
