/// Lenient readers for the server-care responses: a field that is missing or
/// of another type reads as null, never as an error, so one odd value cannot
/// hide the rest of a response.
Map<String, dynamic>? readMap(Object? value) {
  if (value is! Map) return null;
  return {
    for (final e in value.entries)
      if (e.key is String) e.key as String: e.value,
  };
}

String? readString(Object? value) => value is String ? value : null;

/// A version string, or null when Hermes reports none: an empty text or the
/// word "unknown" (what a checkout without version metadata answers) is not
/// a version to show.
String? readVersion(Object? value) {
  final text = readString(value)?.trim();
  if (text == null || text.isEmpty || text.toLowerCase() == 'unknown') {
    return null;
  }
  return text;
}

bool? readBool(Object? value) => value is bool ? value : null;

int? readInt(Object? value) {
  if (value is int) return value;
  if (value is double && value.isFinite) return value.toInt();
  return null;
}

double? readDouble(Object? value) {
  if (value is num && value.isFinite) return value.toDouble();
  return null;
}

/// The strings of a list, skipping anything else.
List<String> readStrings(Object? value) =>
    value is List ? [for (final e in value) ?readString(e)] : const [];

/// The maps of a list, skipping anything else.
List<Map<String, dynamic>> readMaps(Object? value) =>
    value is List ? [for (final e in value) ?readMap(e)] : const [];
