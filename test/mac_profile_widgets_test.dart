import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:hermes_app/src/profiles/widgets/mac_profile_switcher.dart';
import 'package:hermes_app/src/profiles/widgets/mac_profiles_view.dart';
import 'package:hermes_app/src/profiles/widgets/profile_avatar.dart';
import 'package:hermes_app/src/settings/widgets/mac_account_footer.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

const _profiles = [
  HermesProfile(
    name: 'default',
    description: 'Everyday',
    path: '/home/hermes/.hermes',
  ),
  HermesProfile(
    name: 'work',
    displayName: 'Work',
    description: 'Day job',
    path: '/home/hermes/.hermes/profiles/work',
  ),
];

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view
    ..physicalSize = const Size(1200, 800)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildHermesLightTheme(platform: TargetPlatform.macOS),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  test('initials take the first letters of two words', () {
    expect(initialsOf('Ada Lovelace'), 'AL');
    expect(initialsOf('work'), 'W');
    expect(initialsOf('ada.lovelace@example.com'), 'AL');
    expect(initialsOf(''), '?');
  });

  group('MacProfileSwitcher', () {
    late List<String> events;

    Future<void> pumpSwitcher(WidgetTester tester) {
      events = [];
      return _pump(
        tester,
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 260,
            child: MacProfileSwitcher(
              profiles: _profiles,
              current: 'default',
              onSwitch: (name) => events.add('switch:$name'),
              onNewProfile: () => events.add('new'),
              onManage: () => events.add('manage'),
            ),
          ),
        ),
      );
    }

    testWidgets('is a 40pt card with the profile and its description', (
      tester,
    ) async {
      await pumpSwitcher(tester);
      expect(
        tester.getSize(find.byKey(const Key('mac-profile-switcher'))).height,
        40,
      );
      expect(find.text('default'), findsOneWidget);
      expect(find.text('Everyday'), findsOneWidget);
    });

    testWidgets('lists every profile with its home and switches', (
      tester,
    ) async {
      await pumpSwitcher(tester);
      await tester.tap(find.byKey(const Key('mac-profile-switcher')));
      await tester.pumpAndSettle();

      expect(find.text('Profiles'), findsOneWidget);
      expect(find.text('/home/hermes/.hermes/profiles/work'), findsOneWidget);
      expect(find.text('New Profile…'), findsOneWidget);
      expect(find.text('Manage Profiles…'), findsOneWidget);
      expect(
        tester
            .getSize(
              find.ancestor(
                of: find.text('Work'),
                matching: find.byWidgetPredicate((w) => w is PopupMenuItem),
              ),
            )
            .height,
        36,
      );

      await tester.tap(find.text('Work'));
      await tester.pumpAndSettle();
      expect(events, ['switch:work']);
    });

    testWidgets('picking the current profile switches nothing', (tester) async {
      await pumpSwitcher(tester);
      await tester.tap(find.byKey(const Key('mac-profile-switcher')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('default').last);
      await tester.pumpAndSettle();
      expect(events, isEmpty);
    });

    testWidgets('offers New Profile and Manage Profiles', (tester) async {
      await pumpSwitcher(tester);
      await tester.tap(find.byKey(const Key('mac-profile-switcher')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manage Profiles…'));
      await tester.pumpAndSettle();
      expect(events, ['manage']);
    });
  });

  group('MacProfilesView', () {
    testWidgets('shows the selected home with counts, none for a failure', (
      tester,
    ) async {
      final opened = <ProfileSection>[];
      await _pump(
        tester,
        MacProfilesView(
          profiles: _profiles,
          selected: 'work',
          onSelect: (_) {},
          counts: const {ProfileSection.skills: 12, ProfileSection.mcp: 0},
          onOpen: opened.add,
        ),
      );

      expect(find.text('/home/hermes/.hermes/profiles/work'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('profile-section-messaging')),
          matching: find.byType(Text),
        ),
        findsNWidgets(2),
      );
      expect(find.textContaining("this profile's home"), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('profile-row-work'))).height,
        44,
      );

      await tester.tap(find.byKey(const ValueKey('profile-section-plugins')));
      expect(opened, [ProfileSection.plugins]);
    });
  });

  group('MacAccountFooter', () {
    Future<List<String>> pumpFooter(
      WidgetTester tester, {
      bool signIn = true,
    }) async {
      final events = <String>[];
      await _pump(
        tester,
        Align(
          alignment: Alignment.bottomLeft,
          child: SizedBox(
            width: 260,
            child: MacAccountFooter(
              name: 'Ada Lovelace',
              host: 'hermes.example.com',
              onSettings: () => events.add('settings'),
              onConnection: () => events.add('connection'),
              onSignOut: signIn ? () => events.add('sign-out') : null,
            ),
          ),
        ),
      );
      return events;
    }

    testWidgets('shows initials, name and host', (tester) async {
      await pumpFooter(tester);
      expect(find.text('AL'), findsOneWidget);
      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(find.text('hermes.example.com'), findsOneWidget);
    });

    testWidgets('its menu offers settings, connection and sign out', (
      tester,
    ) async {
      final events = await pumpFooter(tester);
      await tester.tap(find.byKey(const Key('mac-account-footer')));
      await tester.pumpAndSettle();

      expect(find.text('Signed in to the dashboard'), findsOneWidget);
      expect(find.text('⌘,'), findsOneWidget);
      expect(find.text('Connection Details'), findsOneWidget);
      await tester.tap(find.text('Sign Out'));
      await tester.pumpAndSettle();
      expect(events, ['sign-out']);
    });

    testWidgets('a server without sign-in has no Sign Out', (tester) async {
      await pumpFooter(tester, signIn: false);
      await tester.tap(find.byKey(const Key('mac-account-footer')));
      await tester.pumpAndSettle();
      expect(find.text('Sign Out'), findsNothing);
      expect(find.text('Connected to the dashboard'), findsOneWidget);
    });
  });
}
