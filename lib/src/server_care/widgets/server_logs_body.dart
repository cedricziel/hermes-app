import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../widgets/content_column.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/state_message.dart';
import '../log_line.dart';
import 'log_level_menu_button.dart';
import 'log_line_tile.dart';

/// What the Logs page has to show.
enum ServerLogsStatus {
  /// A read is running and nothing is known yet.
  loading,

  /// Lines to show.
  ready,

  /// The log has no lines and no filter is set.
  empty,

  /// A level or search leaves no lines.
  noMatch,

  /// The server could not be reached.
  offline,

  /// Hermes refused, with [ServerLogsBody.refusedMessage] as its reason.
  refused,

  /// The read failed for another reason.
  failed,
}

/// The day a log entry was written, from its server timestamp
/// (`2026-11-14 09:12:03,114`); null when it has none or it cannot be read.
DateTime? logEntryDay(LogLine line) {
  final time = line.time;
  if (time == null || time.length < 10) return null;
  final day = DateTime.tryParse(time.substring(0, 10));
  return day == null ? null : DateTime(day.year, day.month, day.day);
}

/// The clock time of a log entry ("09:12:03"); the stamp as written when it
/// does not look like a date and time.
String? logEntryClock(LogLine line) {
  final time = line.time;
  if (time == null) return null;
  final m = RegExp(r'\d{2}:\d{2}:\d{2}').firstMatch(time);
  return m?.group(0) ?? time;
}

/// The Logs page under its bar: the level menu, then the lines newest first
/// under sticky day headers, or the state that takes their place. Models and
/// callbacks only; the page owns the controller.
class ServerLogsBody extends StatelessWidget {
  const ServerLogsBody({
    super.key,
    required this.status,
    this.entries = const [],
    required this.level,
    required this.onLevel,
    this.refusedMessage,
    this.canShowOlder = false,
    this.lastLinesCount,
    this.onShowOlder,
    this.onClearFilters,
    this.onRetry,
    this.now,
  });

  final ServerLogsStatus status;

  /// The entries to show, newest first.
  final List<LogLine> entries;
  final LogLevelFilter level;
  final ValueChanged<LogLevelFilter> onLevel;

  /// Hermes' own words for [ServerLogsStatus.refused].
  final String? refusedMessage;

  /// Whether "Show older lines" is offered at the end.
  final bool canShowOlder;

  /// When set, the end of the list says these are the last lines.
  final int? lastLinesCount;
  final VoidCallback? onShowOlder;
  final VoidCallback? onClearFilters;
  final VoidCallback? onRetry;

  /// Today, for "Today" and "Yesterday"; the clock when null.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final menu = SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: LogLevelMenuButton(value: level, onChanged: onLevel),
        ),
      ),
    );
    final retry = onRetry == null
        ? null
        : FilledButton(
            onPressed: onRetry,
            child: Text(l10n.serverCareTryAgain),
          );
    final Widget? state = switch (status) {
      ServerLogsStatus.loading || ServerLogsStatus.ready => null,
      ServerLogsStatus.empty => StateMessage(
        icon: AppIcons.info,
        title: l10n.serverCareLogsEmptyTitle,
        detail: l10n.serverCareLogsEmptyDetail,
      ),
      ServerLogsStatus.noMatch => StateMessage(
        icon: AppIcons.info,
        title: l10n.serverCareLogsNoMatchTitle,
        detail: l10n.serverCareLogsNoMatchDetail,
        action: onClearFilters == null
            ? null
            : FilledButton(
                onPressed: onClearFilters,
                child: Text(l10n.serverCareLogsClearFilters),
              ),
      ),
      ServerLogsStatus.offline => StateMessage(
        icon: AppIcons.warning,
        title: l10n.serverCareHeadlineOffline,
        detail: l10n.serverCareHeadlineOfflineDetail,
        action: retry,
      ),
      ServerLogsStatus.refused => StateMessage(
        icon: AppIcons.error,
        title: l10n.serverCareLogsFailedTitle,
        detail: refusedMessage ?? l10n.serverCareLogsFailedDetail,
        action: retry,
      ),
      ServerLogsStatus.failed => StateMessage(
        icon: AppIcons.error,
        title: l10n.serverCareLogsFailedTitle,
        detail: l10n.serverCareLogsFailedDetail,
        action: retry,
      ),
    };
    return ContentColumn(
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          menu,
          if (state != null)
            SliverToBoxAdapter(child: SizedBox(height: 360, child: state))
          else if (status == ServerLogsStatus.loading)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: LoadingSkeleton(label: l10n.serverCareLogsLoading),
              ),
            )
          else
            ..._sections(context),
        ],
      ),
    );
  }

  List<Widget> _sections(BuildContext context) {
    final l10n = context.l10n;
    final today = _dayOf(now ?? DateTime.now());
    // Entries are grouped by the day on their stamp; one without a stamp
    // belongs to the day of the entry just above it.
    final groups = <(DateTime?, List<LogLine>)>[];
    for (final entry in entries) {
      final day =
          logEntryDay(entry) ?? (groups.isEmpty ? null : groups.last.$1);
      if (groups.isEmpty || groups.last.$1 != day) {
        groups.add((day, [entry]));
      } else {
        groups.last.$2.add(entry);
      }
    }
    String label(DateTime day) {
      if (day == today) return l10n.serverCareLogDayToday;
      if (day == DateTime(today.year, today.month, today.day - 1)) {
        return l10n.serverCareLogDayYesterday;
      }
      return DateFormat.MMMd(l10n.localeName).format(day);
    }

    return [
      for (final (day, lines) in groups)
        if (day == null)
          SliverList.builder(
            itemCount: lines.length,
            itemBuilder: (_, i) => _tile(lines[i]),
          )
        else
          LogDaySection(
            label: label(day),
            itemCount: lines.length,
            itemBuilder: (_, i) => _tile(lines[i]),
          ),
      SliverToBoxAdapter(child: _footer(context)),
    ];
  }

  static DateTime _dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

  Widget _tile(LogLine line) => LogLineTile(
    time: logEntryClock(line),
    level: line.level,
    source: line.source,
    message: line.message ?? line.raw,
    continuation: line.continuation,
  );

  Widget _footer(BuildContext context) {
    final l10n = context.l10n;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        children: [
          if (canShowOlder && onShowOlder != null)
            OutlinedButton(
              onPressed: onShowOlder,
              child: Text(l10n.serverCareLogsShowOlder),
            ),
          if (lastLinesCount case final count?)
            Text(
              l10n.serverCareLogsLastLines(count),
              textAlign: TextAlign.center,
              style: TextStyle(color: muted),
            ),
        ],
      ),
    );
  }
}
