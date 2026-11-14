import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/server_care/widgets/usage_chart.dart';
import 'package:hermes_app/src/server_care/widgets/usage_day_list.dart';
import 'package:hermes_app/src/server_care/widgets/usage_model_list.dart';
import 'package:hermes_app/src/server_care/widgets/usage_totals_card.dart';

Widget _host(Widget child, {Locale? locale}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

const _de = Locale('de');

UsageTotalsCard _totals(UsageChartMetric metric) => UsageTotalsCard(
  metric: metric,
  window: UsageChartWindow.days30,
  tokens: 8400000,
  estimatedCost: 12.4,
  conversations: 112,
  inputTokens: 1200000,
  outputTokens: 812000,
  cacheReadTokens: 400000,
  billedCost: 10.02,
);

List<UsageDayEntry> _entries(int n) => [
  for (var i = 0; i < n; i++)
    UsageDayEntry(
      day: DateTime(2026, 11, 12).subtract(Duration(days: i)),
      tokens: 812000,
      cost: 1.2,
      conversations: 1,
    ),
];

void main() {
  testWidgets('totals in English and German', (tester) async {
    await tester.pumpWidget(_host(_totals(UsageChartMetric.tokens)));
    expect(find.text('8.4M tokens'), findsOneWidget);
    expect(find.text('Last 30 days · 112 conversations'), findsOneWidget);
    expect(
      find.text('Input 1.2M · Output 812K · Cache reads 400K'),
      findsOneWidget,
    );

    await tester.pumpWidget(
      _host(_totals(UsageChartMetric.tokens), locale: _de),
    );
    await tester.pumpAndSettle();
    expect(find.text('8,4 Mio. Tokens'), findsOneWidget);
    expect(find.text('Letzte 30 Tage · 112 Unterhaltungen'), findsOneWidget);
    expect(
      find.text(
        'Eingabe 1,2 Mio. · Ausgabe 812.000 · Cache-Lesevorgänge 400.000',
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(_host(_totals(UsageChartMetric.cost), locale: _de));
    await tester.pumpAndSettle();
    expect(find.text('12,40 \$ geschätzt'), findsOneWidget);
    expect(find.text('Abgerechnet: 10,02 \$'), findsOneWidget);
  });

  testWidgets('day list and model list in German', (tester) async {
    await tester.pumpWidget(
      _host(UsageDayList(days: _entries(12)), locale: _de),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nach Tag'), findsOneWidget);
    expect(find.text('12. Nov'), findsOneWidget);
    expect(find.text('2 weitere Tage anzeigen'), findsOneWidget);

    await tester.pumpWidget(
      _host(
        const UsageModelList(
          models: [
            UsageModelEntry(
              model: 'model-a',
              tokens: 8400000,
              cost: 1.2,
              conversations: 3,
              share: 0.001,
            ),
          ],
        ),
        locale: _de,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nach Modell'), findsOneWidget);
    expect(find.text('<1 %'), findsOneWidget);
    expect(find.text('model-a'), findsOneWidget);
  });
}
