import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/memory/memory_usage.dart';

void main() {
  MemoryUsage usage(List<String> texts, {int? limit}) =>
      MemoryUsage.of(texts, limit: limit);

  test('usage is the entries plus 3 per separator, 0 for none', () {
    expect(usage(const []).used, 0);
    expect(usage(['abc']).used, 3);
    expect(usage(['a' * 300, 'b' * 300, 'c' * 300]).used, 906);
    expect(usage(['a' * 300, 'b' * 300, 'c' * 306]).entries, 3);
  });

  test('characters beyond the BMP count once', () {
    expect(usage(['😀']).used, 1);
    expect(usage(['😀', 'é']).used, 5);
  });

  test('the warning starts at 95% of the limit', () {
    expect(usage(['a' * 94], limit: 100).nearlyFull, isFalse);
    expect(usage(['a' * 95], limit: 100).nearlyFull, isTrue);
    expect(usage(['a' * 95]).nearlyFull, isFalse);
  });

  test('left counts the draft in place of the original entry', () {
    final about = usage(['a' * 300, 'b' * 300, 'c' * 306], limit: 1375);
    expect(about.used, 912);
    expect(about.left, 463);
    expect(about.leftWith(original: 'b' * 300, draft: 'b' * 310), 453);
    expect(about.leftWith(original: 'b' * 300, draft: 'b' * 900), -137);
    expect(usage(['a']).leftWith(original: 'a', draft: 'ab'), isNull);
  });

  test('numbers are grouped by thousands', () {
    expect(groupThousands(7), '7');
    expect(groupThousands(1375), '1,375');
    expect(groupThousands(1234567), '1,234,567');
  });

  test('a source picks its tab, unknown ones go to Agent notes', () {
    expect(MemoryTab.forSource('profile'), MemoryTab.aboutYou);
    expect(MemoryTab.forSource('memory'), MemoryTab.agentNotes);
    expect(MemoryTab.forSource(null), MemoryTab.agentNotes);
    expect(MemoryTab.forSource('other'), MemoryTab.agentNotes);
  });
}
