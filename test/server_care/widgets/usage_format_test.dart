import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/server_care/widgets/usage_format.dart';

void main() {
  test('formatCompact', () {
    expect(formatCompact(0), '0');
    expect(formatCompact(999), '999');
    expect(formatCompact(1000), '1K');
    expect(formatCompact(12500), '12.5K');
    expect(formatCompact(400000), '400K');
    expect(formatCompact(812000), '812K');
    expect(formatCompact(999600), '1M');
    expect(formatCompact(1200000), '1.2M');
    expect(formatCompact(8400000), '8.4M');
    expect(formatCompact(12000000), '12M');
    expect(formatCompact(150000000), '150M');
    expect(formatCompact(2500000000), '2.5B');
  });

  test('formatCompactSpoken', () {
    expect(formatCompactSpoken(812000), '812 thousand');
    expect(formatCompactSpoken(8400000), '8.4 million');
    expect(formatCompactSpoken(1200000), '1.2 million');
    expect(formatCompactSpoken(40), '40');
  });

  test('formatDollars always has two decimals', () {
    expect(formatDollars(0.6), '\$0.60');
    expect(formatDollars(1.2), '\$1.20');
    expect(formatDollars(12.4), '\$12.40');
    expect(formatDollars(10.016), '\$10.02');
    expect(formatDollars(1234.5), '\$1,234.50');
    expect(formatDollars(0), '\$0.00');
  });

  test('counts use the singular for one', () {
    expect(formatTokens(1), '1 token');
    expect(formatTokens(812000), '812K tokens');
    expect(formatTokensSpoken(812000), '812 thousand tokens');
    expect(formatConversations(1), '1 conversation');
    expect(formatConversations(9), '9 conversations');
  });

  test('formatShare', () {
    expect(formatShare(0.92), '92%');
    expect(formatShare(0.001), '<1%');
    expect(formatShare(0), '0%');
    expect(formatShare(1), '100%');
  });

  test('days', () {
    final day = DateTime(2026, 11, 12);
    expect(formatDayShort(day), '12 Nov');
    expect(formatDayLong(day), '12 November');
    expect(formatMonthShort(day), 'Nov');
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
