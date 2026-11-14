const _shortMonths = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const _longMonths = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// "12 Nov".
String formatDayShort(DateTime day) =>
    '${day.day} ${_shortMonths[day.month - 1]}';

/// "12 November", for screen readers.
String formatDayLong(DateTime day) =>
    '${day.day} ${_longMonths[day.month - 1]}';

/// "Nov", the 90-day chart's axis label.
String formatMonthShort(DateTime day) => _shortMonths[day.month - 1];

/// A number scaled to thousands, millions or billions: the digits and the
/// unit index (0 none, 1 thousand, 2 million, 3 billion). One decimal under
/// 100 and none above; a value that rounds up to 1000 moves to the next unit.
(String, int) _scaled(num value) {
  final n = value.abs();
  if (n.round() < 1000) return (n.round().toString(), 0);
  double round(double v) => v < 100 ? (v * 10).round() / 10 : v.roundToDouble();
  var scaled = n / 1000;
  var unit = 1;
  while (unit < 3 && round(scaled) >= 1000) {
    scaled /= 1000;
    unit++;
  }
  final text = round(scaled).toString();
  return (
    text.endsWith('.0') ? text.substring(0, text.length - 2) : text,
    unit,
  );
}

/// "812K", "8.4M", "1.2M", "520", "1.5B".
String formatCompact(num value) {
  final (digits, unit) = _scaled(value);
  return '${value < 0 ? '-' : ''}$digits${const ['', 'K', 'M', 'B'][unit]}';
}

/// "812 thousand", "8.4 million", for screen readers.
String formatCompactSpoken(num value) {
  final (digits, unit) = _scaled(value);
  final word = const ['', ' thousand', ' million', ' billion'][unit];
  return '${value < 0 ? '-' : ''}$digits$word';
}

/// "$12.40", always two decimals, with a separator from a thousand up.
String formatDollars(num value) {
  final fixed = value.abs().toStringAsFixed(2);
  final dot = fixed.indexOf('.');
  final whole = fixed.substring(0, dot);
  final grouped = whole.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return '${value < 0 ? '-' : ''}\$$grouped${fixed.substring(dot)}';
}

/// "812K tokens", "1 token".
String formatTokens(num value) =>
    '${formatCompact(value)} ${value.round() == 1 ? 'token' : 'tokens'}';

/// "812 thousand tokens", for screen readers.
String formatTokensSpoken(num value) =>
    '${formatCompactSpoken(value)} ${value.round() == 1 ? 'token' : 'tokens'}';

/// "9 conversations", "1 conversation".
String formatConversations(int count) =>
    '$count ${count == 1 ? 'conversation' : 'conversations'}';

/// "92%", "<1%" for a share that is not zero but would round to it.
String formatShare(double share) {
  if (share <= 0) return '0%';
  final percent = (share * 100).round();
  return percent < 1 ? '<1%' : '$percent%';
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
