import 'package:intl/intl.dart';

import '../../../l10n/l10n.dart';

/// "12 Nov": the usage table's and the chart's day, in the locale's month
/// names and order.
String formatDayShort(AppLocalizations l10n, DateTime day) =>
    l10n.serverCareUsageDayShort(day, day);

/// "12 November", for screen readers.
String formatDayLong(AppLocalizations l10n, DateTime day) =>
    l10n.serverCareUsageDayLong(day, day);

/// "Nov", the 90-day chart's axis label.
String formatMonthShort(AppLocalizations l10n, DateTime day) =>
    DateFormat.LLL(l10n.localeName).format(day);

/// [value] rounded the way the compact forms show it: a whole number under a
/// thousand, then one decimal of the scaled value under 100 and none above;
/// a value that rounds up to 1000 of a unit moves to the next one.
num _roundedForCompact(num value) {
  final n = value.abs();
  if (n.round() < 1000) return value.round();
  double round(double v) => v < 100 ? (v * 10).round() / 10 : v.roundToDouble();
  var scaled = n / 1000;
  var factor = 1000.0;
  var unit = 1;
  while (unit < 3 && round(scaled) >= 1000) {
    scaled /= 1000;
    factor *= 1000;
    unit++;
  }
  final rounded = round(scaled) * factor;
  return value < 0 ? -rounded : rounded;
}

/// "812K", "8.4M", "1.2M", "520", "1.5B"; in German "8,4 Mio.".
String formatCompact(AppLocalizations l10n, num value) {
  final rounded = _roundedForCompact(value);
  final text = NumberFormat.compact(locale: l10n.localeName).format(rounded);
  // A locale with no short form for thousands (German) leaves the bare
  // digits, which read better grouped.
  return rounded.abs() >= 1000 && RegExp(r'^-?\d+$').hasMatch(text)
      ? NumberFormat.decimalPattern(l10n.localeName).format(rounded)
      : text;
}

/// "812 thousand", "8.4 million", for screen readers.
String formatCompactSpoken(AppLocalizations l10n, num value) =>
    NumberFormat.compactLong(locale: l10n.localeName)
        .format(_roundedForCompact(value));

/// "$12.40": always two decimals, grouped from a thousand up; the locale
/// places the symbol and the separators.
String formatDollars(AppLocalizations l10n, num value) => NumberFormat.currency(
  locale: l10n.localeName,
  symbol: '\$',
  decimalDigits: 2,
).format(value);

/// "812K tokens", "1 token".
String formatTokens(AppLocalizations l10n, num value) =>
    l10n.serverCareUsageTokens(value.round(), formatCompact(l10n, value));

/// "812 thousand tokens", for screen readers.
String formatTokensSpoken(AppLocalizations l10n, num value) =>
    l10n.serverCareUsageTokens(value.round(), formatCompactSpoken(l10n, value));

/// "9 conversations", "1 conversation".
String formatConversations(AppLocalizations l10n, int count) =>
    l10n.serverCareUsageConversations(count);

/// "92%", "<1%" for a share that is not zero but would round to it.
String formatShare(AppLocalizations l10n, double share) {
  final percent = NumberFormat.percentPattern(l10n.localeName);
  if (share <= 0) return percent.format(0);
  final whole = (share * 100).round();
  return whole < 1
      ? l10n.serverCareUsageShareLessThanOne(percent.format(0.01))
      : percent.format(whole / 100);
}

/// The distance between the chart's three gridlines: the smallest round
/// number (1, 2, 3, 4, 5, 6, 8 times a power of ten) at which three lines
/// reach [maxValue], so 1.2M gives 400K and a top day of $1.77 gives $0.60.
/// [fallback] is used when there is nothing to draw.
double usageAxisStep(double maxValue, {required double fallback}) {
  if (!(maxValue > 0)) return fallback;
  final target = maxValue / 3;
  var power = 1.0;
  while (power * 10 <= target * (1 + 1e-12)) {
    power *= 10;
  }
  while (power > target * (1 + 1e-12)) {
    power /= 10;
  }
  for (final mantissa in const [1, 2, 3, 4, 5, 6, 8]) {
    if (mantissa * power >= target * (1 - 1e-9)) {
      return _clean(mantissa * power);
    }
  }
  return _clean(10 * power);
}

/// Drops floating point noise such as 0.6000000000000001.
double _clean(double step) => double.parse(step.toStringAsPrecision(6));
