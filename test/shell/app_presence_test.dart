import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/shell/app_presence.dart';

void main() {
  const mac = TargetPlatform.macOS;

  group('on macOS', () {
    test('a hidden or inactive app is in the foreground but not focused', () {
      for (final state in [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
      ]) {
        expect(
          AppPresence.foreground(state, platform: mac),
          isTrue,
          reason: '$state',
        );
        expect(AppPresence.focused(state), isFalse, reason: '$state');
      }
    });

    test('a resumed app is in the foreground and focused', () {
      expect(
        AppPresence.foreground(AppLifecycleState.resumed, platform: mac),
        isTrue,
      );
      expect(AppPresence.focused(AppLifecycleState.resumed), isTrue);
    });

    test('a paused or detached app is neither', () {
      for (final state in [
        AppLifecycleState.paused,
        AppLifecycleState.detached,
      ]) {
        expect(
          AppPresence.foreground(state, platform: mac),
          isFalse,
          reason: '$state',
        );
        expect(AppPresence.focused(state), isFalse, reason: '$state');
      }
    });
  });

  group('on other platforms', () {
    test('foreground is resumed and nothing else', () {
      for (final platform in [
        TargetPlatform.iOS,
        TargetPlatform.android,
        TargetPlatform.windows,
        TargetPlatform.linux,
      ]) {
        for (final state in AppLifecycleState.values) {
          expect(
            AppPresence.foreground(state, platform: platform),
            state == AppLifecycleState.resumed,
            reason: '$platform $state',
          );
        }
      }
    });
  });

  test('an app that has not reported a state yet is in front', () {
    expect(AppPresence.foreground(null, platform: mac), isTrue);
    expect(AppPresence.foreground(null, platform: TargetPlatform.iOS), isTrue);
    expect(AppPresence.focused(null), isTrue);
  });

  test('windowless is a hidden app on macOS and nothing elsewhere', () {
    expect(
      AppPresence.windowless(AppLifecycleState.hidden, platform: mac),
      isTrue,
    );
    expect(
      AppPresence.windowless(AppLifecycleState.resumed, platform: mac),
      isFalse,
    );
    expect(
      AppPresence.windowless(AppLifecycleState.inactive, platform: mac),
      isFalse,
    );
    expect(
      AppPresence.windowless(
        AppLifecycleState.hidden,
        platform: TargetPlatform.iOS,
      ),
      isFalse,
    );
  });
}
