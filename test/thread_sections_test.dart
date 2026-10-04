import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/thread_sections.dart';

ChatThread _thread(String id, DateTime at, {bool pinned = false}) =>
    ChatThread(id: id, title: id, updatedAt: at, pinned: pinned, remote: true);

void main() {
  final now = DateTime(2026, 10, 4, 15);

  test('sorts threads into pinned, today and the earlier spans', () {
    final sections = groupThreads([
      _thread('pinned-old', DateTime(2025, 1, 1), pinned: true),
      _thread('this-morning', DateTime(2026, 10, 4, 8)),
      _thread('yesterday', DateTime(2026, 10, 3, 23)),
      _thread('last-week', DateTime(2026, 9, 28)),
      _thread('last-month', DateTime(2026, 9, 10)),
      _thread('long-ago', DateTime(2026, 6, 1)),
    ], now: now);

    expect(
      [
        for (final s in sections)
          '${s.kind.label}: ${s.threads.map((t) => t.id).join(', ')}',
      ],
      [
        'Pinned: pinned-old',
        'Today: this-morning',
        'Previous 7 days: yesterday, last-week',
        'Previous 30 days: last-month',
        'Older: long-ago',
      ],
    );
  });

  test('leaves out empty sections and keeps the given order', () {
    final sections = groupThreads([
      _thread('b', DateTime(2026, 10, 4, 9)),
      _thread('a', DateTime(2026, 10, 4, 14)),
    ], now: now);

    expect(sections, hasLength(1));
    expect(sections.single.kind, ThreadSectionKind.today);
    expect([for (final t in sections.single.threads) t.id], ['b', 'a']);
  });

  test('a draft from just now is today', () {
    final sections = groupThreads([
      ChatThread(id: 'draft', title: 'New chat', updatedAt: now),
    ], now: now);
    expect(sections.single.kind, ThreadSectionKind.today);
  });

  test('labels each section', () {
    expect(ThreadSectionKind.values.map((k) => k.label), [
      'Pinned',
      'Today',
      'Previous 7 days',
      'Previous 30 days',
      'Older',
    ]);
  });
}
