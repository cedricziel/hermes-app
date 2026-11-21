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
/// A Swift file without its comments, so a scan cannot match text that is
/// commented out.
String readSwift(String path) =>
    File(path)
        .readAsStringSync()
        .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('//'))
        .join('\n');

void main() {
  test('the native sizes match the Dart constants', () {
    final xib = File('macos/Runner/Base.lproj/MainMenu.xib').readAsStringSync();
    final window = RegExp(
      r'<window [^>]*customClass="MainFlutterWindow".*?'
      r'<rect key="contentRect" x="[\d.]+" y="[\d.]+" '
      r'width="(\d+)" height="(\d+)"/>.*?'
      r'<view key="contentView"[^>]*>\s*'
      r'<rect key="frame" x="[\d.]+" y="[\d.]+" '
      r'width="(\d+)" height="(\d+)"/>',
      dotAll: true,
    ).firstMatch(xib);
    expect(window, isNotNull);
    expect(
      Size(double.parse(window![1]!), double.parse(window[2]!)),
      kMacMainWindowDefaultSize,
    );
    expect(
      Size(double.parse(window[3]!), double.parse(window[4]!)),
      kMacMainWindowDefaultSize,
      reason: 'the content view frame matches the content rect',
    );

    final swift = readSwift('macos/Runner/MainFlutterWindow.swift');
    final minimum = RegExp(
      r'minimumContentSize = NSSize\(width: (\d+), height: (\d+)\)',
    ).firstMatch(swift);
    expect(minimum, isNotNull);
    expect(
      Size(double.parse(minimum![1]!), double.parse(minimum[2]!)),
      kMacMainWindowMinSize,
    );
    // The decisive places: the minimum and the remembered frame are set in
    // awakeFromNib and nothing after it (macos_window_utils included) resets
    // the minimum; no Dart code resizes the window at startup.
    final start = swift.indexOf('override func awakeFromNib()');
    final end = swift.indexOf('super.awakeFromNib()');
    expect(start, isNonNegative);
    expect(end, greaterThan(start));
    final awake = swift
        .substring(start, end)
        .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('//'))
        .join('\n');
    expect(awake, contains('self.contentMinSize = Self.minimumContentSize'));
    final setFrame = awake.indexOf('self.setFrame(windowFrame');
    final center = awake.indexOf('center()');
    expect(setFrame, isNonNegative);
    expect(center, isNonNegative);
    expect(
      center,
      greaterThan(setFrame),
      reason: 'setFrame restores the xib origin, so center() must follow it',
    );
    expect(
      RegExp(r'contentMinSize[\w.]*\s*=[^=]').allMatches(swift),
      hasLength(1),
      reason: 'contentMinSize is set only in awakeFromNib',
    );
    // The saved frame is restored under the final style mask, or AppKit holds a
    // saved 640x480 frame to the minimum plus a title bar.
    final insert = awake.indexOf('self.styleMask.insert(.fullSizeContentView)');
    expect(insert, isNonNegative);
    expect(insert, lessThan(awake.indexOf('setFrameUsingName(')));
    // The remembered frame is AppKit's frame autosave, set once in
    // awakeFromNib; the centred default applies only when none exists.
    expect(
      swift,
      contains('static let frameAutosaveName = "HermesMainWindow"'),
    );
    expect(swift, isNot(contains('isRestorable')));
    expect(
      RegExp(
        r'if setFrameUsingName\(Self\.frameAutosaveName\) \{\s*'
        r'correctSavedFrame\(\)\s*\} else \{\s*center\(\)\s*\}\s*'
        r'setFrameAutosaveName\(Self\.frameAutosaveName\)',
      ).hasMatch(awake),
      isTrue,
    );
    // The one bare center() is the no-saved-frame branch; the screenshot
    // resize (`self?.center()` in the channel handler) is a different call.
    expect(RegExp(r'(?<![?.])\bcenter\(\)').allMatches(awake), hasLength(1));
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      expect(
        file.readAsStringSync(),
        isNot(contains(RegExp(r'setWindowMinSize|setWindowFrame'))),
        reason: file.path,
      );
    }
    final delegate = readSwift('macos/Runner/AppDelegate.swift');
    expect(
      RegExp(r'contentMinSize[\w.]*\s*=[^=]').allMatches(delegate),
      isEmpty,
    );
  });

  test(
    'a saved frame comes back unchanged: only enlarged below the minimum',
    () {
      final swift = readSwift('macos/Runner/MainFlutterWindow.swift');
      final correct = RegExp(
        r'private func correctSavedFrame\(\) \{.*?\n  \}\n',
        dotAll: true,
      ).firstMatch(swift)!.group(0)!;
      // Sizes only grow to the minimum; no content-rect conversion of the saved
      // frame, which loses the title bar (CI measured 900x600 back as 900x568).
      expect(correct, contains('max(frame.width, smallest.width)'));
      expect(correct, contains('max(frame.height, smallest.height)'));
      expect(correct, isNot(contains('contentRect(forFrameRect')));
      expect(correct, isNot(contains('setContentSize')));
      expect(correct, contains('restoredFrame = self.frame'));
      // Dart-side styling happens after awakeFromNib; the runner puts the frame
      // back once it is done.
      expect(swift, contains('case "settleFrame":'));
      expect(
        File('lib/src/macos/mac_window.dart').readAsStringSync(),
        contains("invokeMethod<void>('settleFrame')"),
      );
      // A window AppKit restored in full screen keeps the full-screen frame.
      final settle = RegExp(
        r'case "settleFrame":.*?result\(nil\)',
        dotAll: true,
      ).firstMatch(swift)!.group(0)!;
      expect(
        settle.indexOf('.fullScreen'),
        inInclusiveRange(0, settle.indexOf('window.setFrame(')),
      );
      expect(settle, contains('!window.styleMask.contains(.fullScreen)'));
      // The CI report waits for this flag, so it is set before anything else.
      expect(
        settle.indexOf('self?.frameSettled = true'),
        inInclusiveRange(0, settle.indexOf('if let restored')),
      );
      // The CI round trip resizes the frame, not the content.
      final delegate = readSwift('macos/Runner/AppDelegate.swift');
      final set = delegate.substring(
        delegate.indexOf('HERMES_REPORT_WINDOW_SET'),
      );
      expect(set, contains('window.setFrame('));
      expect(
        set.substring(0, set.indexOf('NSApp.terminate')),
        isNot(contains('setContentSize')),
      );
    },
  );

  test('the CI window report exists only in debug builds and then quits', () {
    final delegate = readSwift('macos/Runner/AppDelegate.swift');
    const flag = 'HERMES_REPORT_WINDOW';
    // The conditionals open at a position: an unrelated `#if os(...)` elsewhere
    // in the file must not matter, only that `#if DEBUG` encloses the flag.
    List<String> openAt(int offset) {
      final open = <String>[];
      for (final line in delegate.substring(0, offset).split('\n')) {
        final t = line.trim();
        if (t.startsWith('#if ')) open.add(t);
        if (t == '#endif' && open.isNotEmpty) open.removeLast();
      }
      return open;
    }

    final hits = flag.allMatches(delegate).toList();
    expect(hits, hasLength(greaterThanOrEqualTo(1)));
    for (final hit in hits) {
      expect(
        openAt(hit.start),
        contains('#if DEBUG'),
        reason: '$flag is not inside an #if DEBUG ... #endif',
      );
    }
    final block = delegate.substring(
      hits.first.start,
      delegate.indexOf('#endif', hits.last.end),
    );
    expect(block, contains('NSApp.terminate(nil)'));
    expect(block, contains('HERMES_WINDOW frame='));
    // The report waits for the settleFrame call and, if it never comes, prints a
    // line the CI check rejects instead of a frame that looks settled.
    expect(
      block,
      contains(
        'let settled = (window as? MainFlutterWindow)?.frameSettled == true',
      ),
    );
    expect(block, contains('if !settled && waited < 10 {'));
    expect(
      block.indexOf('if !settled {'),
      inInclusiveRange(0, block.indexOf('HERMES_WINDOW unsettled')),
    );
    expect(block, contains('HERMES_WINDOW unsettled'));
    expect(
      block.indexOf('HERMES_WINDOW unsettled'),
      lessThan(block.indexOf('HERMES_WINDOW frame=')),
    );
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
