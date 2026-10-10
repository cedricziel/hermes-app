import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/quick_panel/quick_panel_session.dart';

void main() {
  final start = DateTime(2026, 10, 10, 12);

  bool resumeAt(QuickPanelSession session, Duration later, String? profile) =>
      withClock(Clock.fixed(start.add(later)), () => session.resume(profile));

  QuickPanelSession used({String? profile = 'work'}) {
    final session = QuickPanelSession();
    withClock(Clock.fixed(start), () => session.touch(profile));
    return session;
  }

  test('a new panel has no chat to continue', () {
    expect(QuickPanelSession().resume('work'), isFalse);
  });

  test('continues under five minutes on the same profile', () {
    expect(resumeAt(used(), const Duration(minutes: 4), 'work'), isTrue);
  });

  test('starts fresh after five minutes', () {
    final session = used();

    expect(resumeAt(session, const Duration(minutes: 5), 'work'), isFalse);
    expect(resumeAt(session, Duration.zero, 'work'), isFalse);
  });

  test('starts fresh after the profile changed', () {
    expect(resumeAt(used(), const Duration(minutes: 1), 'home'), isFalse);
  });

  test('a dashboard without profiles continues too', () {
    expect(
      resumeAt(used(profile: null), const Duration(minutes: 1), null),
      isTrue,
    );
  });

  test('starts fresh after the chat moved to a window', () {
    final session = used()..clear();

    expect(resumeAt(session, const Duration(minutes: 1), 'work'), isFalse);
  });

  test('each use pushes the five minutes back', () {
    final session = used();
    withClock(
      Clock.fixed(start.add(const Duration(minutes: 4))),
      () => session.touch('work'),
    );

    expect(resumeAt(session, const Duration(minutes: 8), 'work'), isTrue);
  });
}
