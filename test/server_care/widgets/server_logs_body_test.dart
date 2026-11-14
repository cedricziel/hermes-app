import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/server_care/log_line.dart';
import 'package:hermes_app/src/server_care/widgets/log_level_menu_button.dart';
import 'package:hermes_app/src/server_care/widgets/server_logs_body.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

const _lines = [
  LogLine(
    raw: '',
    time: '2026-11-14 09:12:08,114',
    level: LogLevel.error,
    source: 'a.b',
    message: 'today',
  ),
  LogLine(
    raw: '',
    time: '2026-11-13 21:40:12,731',
    level: LogLevel.info,
    source: 'a.b',
    message: 'yesterday',
  ),
  LogLine(
    raw: '',
    time: '2026-11-12 07:30:01,500',
    level: LogLevel.warning,
    source: 'a.b',
    message: 'older',
  ),
  LogLine(raw: '  headerless'),
];

Widget _app(ServerLogsBody body, {String locale = 'en'}) => MaterialApp(
  theme: buildHermesLightTheme(),
  locale: Locale(locale),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: body),
);

ServerLogsBody _body(
  ServerLogsStatus status, {
  List<LogLine> entries = const [],
  bool canShowOlder = false,
  int? lastLinesCount,
  VoidCallback? onShowOlder,
  VoidCallback? onClear,
  VoidCallback? onRetry,
  String? refused,
}) => ServerLogsBody(
  status: status,
  entries: entries,
  level: LogLevelFilter.all,
  onLevel: (_) {},
  canShowOlder: canShowOlder,
  lastLinesCount: lastLinesCount,
  onShowOlder: onShowOlder,
  onClearFilters: onClear,
  onRetry: onRetry,
  refusedMessage: refused,
  now: DateTime(2026, 11, 14, 10),
);

void main() {
  test('reads the day and the clock from a server stamp', () {
    expect(logEntryDay(_lines.first), DateTime(2026, 11, 14));
    expect(logEntryClock(_lines.first), '09:12:08');
    expect(logEntryDay(_lines.last), isNull);
    expect(logEntryClock(_lines.last), isNull);
  });

  testWidgets('groups under Today, Yesterday and a date', (tester) async {
    await tester.pumpWidget(
      _app(_body(ServerLogsStatus.ready, entries: _lines)),
    );
    expect(find.text('Today'), findsWidgets);
    expect(find.text('Yesterday'), findsWidgets);
    expect(find.text('Nov 12'), findsWidgets);
    expect(find.text('09:12:08'), findsOneWidget);
    // An entry that has no stamp stays with the day above it.
    expect(find.text('  headerless'), findsOneWidget);
  });

  testWidgets('speaks German', (tester) async {
    await tester.pumpWidget(
      _app(
        _body(ServerLogsStatus.ready, entries: _lines, lastLinesCount: 500),
        locale: 'de',
      ),
    );
    expect(find.text('Heute'), findsWidgets);
    expect(find.text('Gestern'), findsWidgets);
    expect(find.text('Alle Stufen'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pump();
    expect(find.text('Das sind die letzten 500 Zeilen.'), findsOneWidget);
  });

  testWidgets('the end offers older lines, and says when there are none', (
    tester,
  ) async {
    var older = 0;
    await tester.pumpWidget(
      _app(
        _body(
          ServerLogsStatus.ready,
          entries: _lines,
          canShowOlder: true,
          onShowOlder: () => older++,
        ),
      ),
    );
    await tester.tap(find.text('Show older lines'));
    expect(older, 1);
    expect(find.textContaining("That's the last"), findsNothing);
  });

  testWidgets('each state reads its own words and offers its own button', (
    tester,
  ) async {
    var taps = 0;
    void tap() => taps++;
    Future<void> show(ServerLogsBody b) async => tester.pumpWidget(_app(b));

    await show(_body(ServerLogsStatus.empty));
    expect(find.text('Nothing logged yet'), findsOneWidget);
    expect(find.text("Hermes hasn't written to this log."), findsOneWidget);

    await show(_body(ServerLogsStatus.noMatch, onClear: tap));
    expect(find.text('No lines match'), findsOneWidget);
    await tester.tap(find.text('Clear filters'));

    await show(_body(ServerLogsStatus.offline, onRetry: tap));
    expect(find.text("Can't reach Hermes"), findsOneWidget);
    await tester.tap(find.text('Try again'));

    await show(
      _body(ServerLogsStatus.refused, onRetry: tap, refused: 'Locked.'),
    );
    expect(find.text('Locked.'), findsOneWidget);
    await tester.tap(find.text('Try again'));

    await show(_body(ServerLogsStatus.failed, onRetry: tap));
    expect(find.text('Try again in a moment.'), findsOneWidget);

    await show(_body(ServerLogsStatus.loading));
    expect(find.bySemanticsLabel('Loading logs'), findsOneWidget);
    expect(taps, 3);
  });
}
