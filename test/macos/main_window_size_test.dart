import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_screen.dart';
import 'package:hermes_app/src/macos/mac_window.dart';
import 'package:hermes_app/src/shell/app_shell.dart';
import 'package:hermes_app/src/theme/breakpoints.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../widgetbook/catalog_auth.dart';
import '../support/fake_hermes_server.dart';

/// The Mac main window cannot be resized below [kMacMainWindowMinSize], and
/// the home shell must lay out there without an overflow.
void main() {
  test('the native sizes match the Dart constants', () {
    final xib = File('macos/Runner/Base.lproj/MainMenu.xib').readAsStringSync();
    final window = RegExp(
      r'<window [^>]*customClass="MainFlutterWindow".*?'
      r'<rect key="contentRect" x="[\d.]+" y="[\d.]+" '
      r'width="(\d+)" height="(\d+)"/>',
      dotAll: true,
    ).firstMatch(xib);
    expect(window, isNotNull);
    expect(
      Size(double.parse(window![1]!), double.parse(window[2]!)),
      kMacMainWindowDefaultSize,
    );

    final swift = File('macos/Runner/MainFlutterWindow.swift')
        .readAsStringSync();
    final minimum = RegExp(
      r'minimumContentSize = NSSize\(width: (\d+), height: (\d+)\)',
    ).firstMatch(swift);
    expect(minimum, isNotNull);
    expect(
      Size(double.parse(minimum![1]!), double.parse(minimum[2]!)),
      kMacMainWindowMinSize,
    );
    // The decisive places: the minimum and the centring are set in
    // awakeFromNib and nothing after it (macos_window_utils included) resets
    // the minimum; no Dart code resizes the window at startup; the xib window
    // stays restorable.
    final start = swift.indexOf('override func awakeFromNib()');
    final end = swift.indexOf('super.awakeFromNib()');
    expect(start, isNonNegative);
    expect(end, greaterThan(start));
    final awake = swift
        .substring(start, end)
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('//'))
        .join('\n');
    expect(awake, contains('self.contentMinSize = Self.minimumContentSize'));
    expect(awake, contains('self.center()'));
    expect(
      RegExp(r'contentMinSize\s*=').allMatches(swift),
      hasLength(1),
      reason: 'contentMinSize is set only in awakeFromNib',
    );
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      expect(
        file.readAsStringSync(),
        isNot(contains(RegExp(r'setWindowMinSize|setWindowFrame'))),
        reason: file.path,
      );
    }
    expect(xib, isNot(contains('restorable="NO"')));
    final delegate = File('macos/Runner/AppDelegate.swift').readAsStringSync();
    expect(delegate, isNot(contains('contentMinSize')));
  });

  group('home shell', () {
    late FakeHermesServer server;

    setUp(() {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      server = FakeHermesServer()
        ..on(
          'GET',
          '/api/profiles',
          profileListBody([profileRow(name: 'default', isDefault: true)]),
        )
        ..on(
          'GET',
          '/api/profiles/active',
          activeProfileBody(active: 'default'),
        )
        ..on(
          'GET',
          '/api/sessions',
          sessionListBody([
            sessionRow(id: 'd1', title: 'Plan the release', pinned: true),
            sessionRow(id: 'd2', title: 'Fix the flaky login test'),
          ]),
        )
        ..on('GET', '/api/sessions/d1/messages', messageListBody('d1', []))
        ..on('GET', '/api/mcp/servers', mcpServerListBody([]));
    });

    Future<void> pumpShell(WidgetTester tester, Size size) async {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final auth = CatalogAuth(server: server, gated: true);
      addTearDown(auth.dispose);
      await tester.pumpWidget(
        withAppProviders(
          auth,
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildHermesLightTheme(platform: TargetPlatform.macOS),
            home: const AppShell(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    for (final (name, size) in [
      ('minimum', kMacMainWindowMinSize),
      (
        'minimum below the toolbar',
        Size(
          kMacMainWindowMinSize.width,
          kMacMainWindowMinSize.height - kMacToolbarHeight,
        ),
      ),
      ('default', kMacMainWindowDefaultSize),
    ]) {
      testWidgets('at the $name window size has no overflow', (tester) async {
        await pumpShell(tester, size);

        expect(find.byType(AppShell), findsOneWidget);
        expect(tester.takeException(), isNull);
      }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

      testWidgets(
        'with an open chat at the $name window size has no overflow',
        (tester) async {
          await pumpShell(tester, size);
          if (find.text('Plan the release').evaluate().isEmpty) {
            await tester.tap(
              find.byKey(const Key('mac-sidebar-toggle')).hitTestable().first,
            );
            await tester.pumpAndSettle();
          }
          await tester.tap(find.text('Plan the release').first);
          await tester.pumpAndSettle();

          expect(find.byType(ChatScreen), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.macOS),
      );
    }
  });
}
