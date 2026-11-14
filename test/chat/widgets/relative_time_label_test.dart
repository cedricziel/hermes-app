import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/chat/widgets/relative_time.dart';

void main() {
  final now = DateTime(2026, 11, 14, 10, 40);

  test('reads inside a sentence, from just now to a date', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    String label(Duration ago, {bool bare = false}) =>
        relativeTimeLabel(l10n, now.subtract(ago), now: now, bareDate: bare);
    expect(label(const Duration(seconds: 20)), 'just now');
    expect(label(const Duration(minutes: 12)), '12 min ago');
    expect(label(const Duration(hours: 3)), '3 h ago');
    expect(label(const Duration(hours: 20)), 'yesterday');
    expect(label(const Duration(days: 4)), '4 days ago');
    expect(label(const Duration(days: 11)), 'on November 3');
    expect(label(const Duration(days: 11), bare: true), 'November 3');
    // A clock that is off never reads as the future.
    expect(label(const Duration(minutes: -5)), 'just now');
  });

  test('the exact time for a screen reader', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(exactTimeLabel(l10n, now), 'November 14, 2026 at 10:40');
  });
}
