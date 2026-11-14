/// Readers for JSON answers of the agent and program methods: each takes any
/// value and answers null for one of the wrong kind, so a parser never throws.
library;

/// A non-empty string, or null.
String? readString(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

/// A finite number from an int, a double or a numeric string.
num? readNumber(Object? value) {
  if (value is num) return value.isFinite ? value : null;
  if (value is String) {
    final parsed = num.tryParse(value.trim());
    return parsed != null && parsed.isFinite ? parsed : null;
  }
  return null;
}

int? readInt(Object? value) => readNumber(value)?.toInt();

bool? readBool(Object? value) => value is bool ? value : null;

/// A UTC time from Unix seconds.
DateTime? readSeconds(Object? value) {
  final seconds = readNumber(value);
  if (seconds == null) return null;
  try {
    return DateTime.fromMillisecondsSinceEpoch(
      (seconds * 1000).round(),
      isUtc: true,
    );
  } on Object {
    return null;
  }
}
