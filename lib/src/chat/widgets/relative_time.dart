import 'package:intl/intl.dart';

import '../../../l10n/l10n.dart';

/// Formats a timestamp as a short relative label ("3m ago", "Yesterday")
/// for thread list rows, without pulling in `intl` for a design preview.
String relativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';
}

/// When [time] was, in words that also read inside a sentence: "just now",
/// "12 min ago", "3 h ago", "yesterday", "4 days ago", then "on 3 November"
/// ("3 November" with [bareDate], after a word such as "Since"). A time in
/// the future (a clock that is off) reads "just now".
String relativeTimeLabel(
  AppLocalizations l10n,
  DateTime time, {
  DateTime? now,
  bool bareDate = false,
}) {
  final at = time.toLocal();
  final current = (now ?? DateTime.now()).toLocal();
  final diff = current.difference(at);
  if (diff.inMinutes < 1) return l10n.chatCheckpointsPageTimeJustNow;
  if (diff.inMinutes < 60) {
    return l10n.chatCheckpointsPageTimeMinutes(diff.inMinutes);
  }
  final today = DateTime(current.year, current.month, current.day);
  final day = DateTime(at.year, at.month, at.day);
  final days = today.difference(day).inDays;
  if (days == 0) return l10n.chatCheckpointsPageTimeHours(diff.inHours);
  if (days == 1) return l10n.chatCheckpointsPageTimeYesterday;
  if (days < 7) return l10n.chatCheckpointsPageTimeDays(days);
  final date = _format(
    l10n,
    at,
    at.year == current.year ? DateFormat.MMMMd : DateFormat.yMMMMd,
  );
  return bareDate ? date : l10n.chatCheckpointsPageTimeDate(date);
}

/// The exact time of [time] for a screen reader: "14 November 2026 at
/// 10:40".
String exactTimeLabel(AppLocalizations l10n, DateTime time) {
  final at = time.toLocal();
  return l10n.chatCheckpointsPageTimeExact(
    _format(l10n, at, DateFormat.yMMMMd),
    _format(l10n, at, DateFormat.Hm),
  );
}

/// [at] in [l10n]'s locale, or in English where that locale's date names
/// were not loaded (no localizations delegate above the widget).
String _format(
  AppLocalizations l10n,
  DateTime at,
  DateFormat Function([String? locale]) pattern,
) {
  try {
    return pattern(l10n.localeName).format(at);
  } on Object {
    return pattern('en_US').format(at);
  }
}
