import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/server_care/widgets/usage_format.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final de = lookupAppLocalizations(const Locale('de'));
  setUpAll(() => initializeDateFormatting('de'));

  test('formatCompact', () {
    expect(formatCompact(en, 0), '0');
    expect(formatCompact(en, 999), '999');
    expect(formatCompact(en, 1000), '1K');
    expect(formatCompact(en, 12500), '12.5K');
    expect(formatCompact(en, 400000), '400K');
    expect(formatCompact(en, 812000), '812K');
    expect(formatCompact(en, 999600), '1M');
    expect(formatCompact(en, 1200000), '1.2M');
    expect(formatCompact(en, 8400000), '8.4M');
    expect(formatCompact(en, 12000000), '12M');
    expect(formatCompact(en, 150000000), '150M');
    expect(formatCompact(en, 2500000000), '2.5B');
  });

  test('formatCompactSpoken', () {
    expect(formatCompactSpoken(en, 812000), '812 thousand');
    expect(formatCompactSpoken(en, 8400000), '8.4 million');
    expect(formatCompactSpoken(en, 1200000), '1.2 million');
    expect(formatCompactSpoken(en, 40), '40');
  });

  test('formatDollars always has two decimals', () {
    expect(formatDollars(en, 0.6), '\$0.60');
    expect(formatDollars(en, 1.2), '\$1.20');
    expect(formatDollars(en, 12.4), '\$12.40');
    expect(formatDollars(en, 10.016), '\$10.02');
    expect(formatDollars(en, 1234.5), '\$1,234.50');
    expect(formatDollars(en, 0), '\$0.00');
  });

  test('counts use the singular for one', () {
    expect(formatTokens(en, 1), '1 token');
    expect(formatTokens(en, 812000), '812K tokens');
    expect(formatTokensSpoken(en, 812000), '812 thousand tokens');
    expect(formatConversations(en, 1), '1 conversation');
    expect(formatConversations(en, 9), '9 conversations');
  });

  test('formatShare', () {
    expect(formatShare(en, 0.92), '92%');
    expect(formatShare(en, 0.001), '<1%');
    expect(formatShare(en, 0), '0%');
    expect(formatShare(en, 1), '100%');
  });

  test('days', () {
    final day = DateTime(2026, 11, 12);
    expect(formatDayShort(en, day), '12 Nov');
    expect(formatDayLong(en, day), '12 November');
    expect(formatMonthShort(en, day), 'Nov');
  });

  test('numbers, money, counts and days follow the locale', () {
    expect(formatCompact(de, 8400000), '8,4\u00A0Mio.');
    expect(formatCompact(de, 2500000000), '2,5\u00A0Mrd.');
    expect(formatCompactSpoken(de, 1200000), '1,2 Millionen');
    expect(formatCompactSpoken(de, 812000), '812 Tausend');
    expect(formatDollars(de, 1234.5), '1.234,50\u00A0\$');
    expect(formatTokens(de, 1), '1 Token');
    expect(formatTokensSpoken(de, 1200000), '1,2 Millionen Tokens');
    expect(formatConversations(de, 1), '1 Unterhaltung');
    expect(formatConversations(de, 1234), '1.234 Unterhaltungen');
    expect(formatShare(de, 0.92), '92\u00A0%');
    expect(formatShare(de, 0.001), '<1\u00A0%');
    final day = DateTime(2026, 11, 12);
    expect(formatDayShort(de, day), '12. Nov');
    expect(formatDayLong(de, day), '12. November');
    expect(formatMonthShort(de, DateTime(2026, 3, 1)), 'Mär');
  });

  test('usageAxisStep gives the gridlines of the design', () {
    expect(usageAxisStep(1200000, fallback: 1), 400000);
    expect(usageAxisStep(1770000, fallback: 1), 600000);
    expect(usageAxisStep(1.77, fallback: 1), 0.6);
    expect(usageAxisStep(1.2, fallback: 1), 0.4);
    expect(usageAxisStep(0, fallback: 7), 7);
    expect(usageAxisStep(3000, fallback: 1), 1000);
    expect(usageAxisStep(3100, fallback: 1), 2000);
  });
}
