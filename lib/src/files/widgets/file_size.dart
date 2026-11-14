import 'package:intl/intl.dart';

import '../../../l10n/l10n.dart';

/// The unit a byte count is written in. Sizes count in steps of 1,024.
enum ByteUnit {
  bytes,
  kilobytes,
  megabytes,
  gigabytes;

  int get factor => switch (this) {
    bytes => 1,
    kilobytes => 1024,
    megabytes => 1024 * 1024,
    gigabytes => 1024 * 1024 * 1024,
  };
}

/// One decimal below 10 (dropped when it is zero) and none from there:
/// "1.8 KB", "3 MB", "14 MB", "212 MB".
NumberFormat _format(String locale, double value) =>
    NumberFormat(value < 9.95 ? '#,##0.#' : '#,##0', locale);

double _scaled(int bytes, ByteUnit unit) => bytes / unit.factor;

/// The unit [bytes] reads best in: the largest one whose value is at least
/// one, bumped when rounding would write "1024 KB".
ByteUnit byteUnitFor(int bytes) {
  var unit = ByteUnit.bytes;
  for (final candidate in ByteUnit.values) {
    if (bytes >= candidate.factor) unit = candidate;
  }
  if (unit != ByteUnit.gigabytes && unit != ByteUnit.bytes) {
    final value = _scaled(bytes, unit);
    final rounded = value < 9.95 ? (value * 10).round() / 10 : value.round();
    if (rounded >= 1024) return ByteUnit.values[unit.index + 1];
  }
  return unit;
}

/// The number of [bytes] in [unit], formatted for [locale], with no unit
/// word: "1.8", "14", "512".
String formatByteNumber(String locale, int bytes, ByteUnit unit) {
  if (unit == ByteUnit.bytes) {
    return NumberFormat.decimalPattern(locale).format(bytes);
  }
  final value = _scaled(bytes, unit);
  return _format(locale, value).format(value);
}

/// [bytes] as the user reads a size: "512 bytes", "1.8 KB", "212 MB". The
/// number follows the locale's separators. Pass [unit] to write several sizes
/// in the same unit, as a progress line does.
String formatByteSize(AppLocalizations l10n, int bytes, {ByteUnit? unit}) {
  final chosen = unit ?? byteUnitFor(bytes < 0 ? 0 : bytes);
  final count = bytes < 0 ? 0 : bytes;
  if (chosen == ByteUnit.bytes) return l10n.filesSizeBytes(count);
  final number = formatByteNumber(l10n.localeName, count, chosen);
  return switch (chosen) {
    ByteUnit.kilobytes => l10n.filesSizeKilobytes(number),
    ByteUnit.megabytes => l10n.filesSizeMegabytes(number),
    _ => l10n.filesSizeGigabytes(number),
  };
}

/// "Downloading… 14 of 30 MB": both amounts in the total's unit, the unit
/// written once.
String formatDownloadProgress(AppLocalizations l10n, int received, int total) {
  final unit = byteUnitFor(total);
  return l10n.filesDownloadProgress(
    formatByteNumber(l10n.localeName, received, unit),
    formatByteSize(l10n, total, unit: unit),
  );
}
