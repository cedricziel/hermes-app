import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/chat/media/media_source.dart';
import 'package:hermes_app/src/chat/media/media_store.dart';
import 'package:hermes_app/src/chat/widgets/quick_look_target.dart';
import 'package:hermes_app/src/files/files_models.dart';
import 'package:hermes_app/src/files/files_preview_page.dart';
import 'package:hermes_app/src/files/files_screen.dart';
import 'package:hermes_app/src/files/server_path.dart';
import 'package:hermes_app/src/files/widgets/file_preview_cover.dart';
import 'package:hermes_app/src/files/widgets/file_preview_header.dart';
import 'package:hermes_app/src/files/widgets/files_spinner.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/attachment_fixtures.dart';
import '../support/fake_device_authenticator.dart';
import '../support/fake_files_source.dart';
import '../support/fake_hermes_server.dart';
import '../support/fake_media_actions.dart';
import '../support/fake_quick_look.dart';

bool _stale = false;
ValueNotifier<int> _changed = ValueNotifier(0);
AppLockController? _lock;

void main() {
  late FakeFilesSource source;
  late FakeMediaActions actions;
  late FakeQuickLook quickLook;
  late Directory cache;
  late MediaStore media;

  setUp(() {
    source = FakeFilesSource();
    actions = FakeMediaActions();
    quickLook = FakeQuickLook();
    cache = tempDir('files_screen');
    media = MediaStore(
      source: HermesMediaSource(() => FakeHermesServer().client()),
      cacheDirectory: () async => cache,
      actions: actions,
      quickLook: quickLook,
    );
    source.lists['/srv/p'] = () => listing([
      folderEntry('/srv/p/reports'),
      file('/srv/p/export.zip'),
      file('/srv/p/api_token.txt'),
      file('/srv/p/deploy.pem'),
      file('/srv/p/notes.txt'),
    ]);
    source.gitRoots['/srv/p'] = () => ok<ServerPath?>(null);
    source.lists['/srv/p/reports'] = () =>
        listing([file('/srv/p/reports/summary.txt')]);
    source.texts['/srv/p/notes.txt'] = () =>
        ok(const FsTextFile(text: 'hello from the notes', byteSize: 20));
    source.downloads['/srv/p/export.zip'] = writes([1, 2, 3], length: 3);
    source.downloads['/srv/p/api_token.txt'] = writes([9], length: 1);
    source.texts['/srv/p/api_token.txt'] = () =>
        ok(const FsTextFile(text: 'KEY=1', byteSize: 5));
  });

  Future<NavigatorState> pump(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    TargetPlatform platform = TargetPlatform.android,
    Listenable? closeWhen,
    bool Function()? shouldClose,
    AppLockController? lock,
    ShareFile? share,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<int>.value(value: 0),
          if (lock != null)
            ChangeNotifierProvider<AppLockController>.value(value: lock),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildHermesLightTheme(platform: platform),
          home: const Scaffold(body: Text('chat')),
        ),
      ),
    );
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => FilesScreen(
            source: source,
            media: media,
            profile: 'work',
            cwd: p('/srv/p'),
            closeWhen: closeWhen,
            shouldClose: shouldClose,
            share: share,
          ),
        ),
      ),
    );
    await settle(tester);
    return navigator;
  }

  group('phone', () {
    testWidgets('the list is a page and a file is pushed over it', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('export.zip'), findsOneWidget);
      expect(find.byType(FilesPreviewPane), findsNothing);

      await tester.tap(find.text('notes.txt'));
      await settle(tester);

      expect(find.byType(FilesPreviewPage), findsOneWidget);
      expect(find.text('hello from the notes'), findsOneWidget);
    });

    testWidgets('reduced motion pushes the preview without a transition', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await pump(tester);
      await tester.tap(find.text('notes.txt'));
      await settle(tester);

      final route = ModalRoute.of(
        tester.element(find.byType(FilesPreviewPage)),
      );
      expect(route, isA<PageRouteBuilder<void>>());
      expect(
        (route! as PageRouteBuilder<void>).transitionDuration,
        Duration.zero,
      );
    });

    testWidgets('back from the preview shows the list again', (tester) async {
      await pump(tester);
      await tester.tap(find.text('notes.txt'));
      await settle(tester);

      await tester.pageBack();
      await settle(tester);

      expect(find.byType(FilesPreviewPage), findsNothing);
      expect(find.text('export.zip'), findsOneWidget);
    });

    testWidgets('Android back goes up a folder before it leaves the page', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.text('reports'));
      await settle(tester);
      expect(find.text('summary.txt'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.text('export.zip'), findsOneWidget);
      expect(find.byType(FilesScreen), findsOneWidget);

      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.byType(FilesScreen), findsNothing);
    });

    testWidgets('a secret file asks first and Cancel fetches nothing', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.text('api_token.txt'));
      await settle(tester);
      expect(find.textContaining('passwords or keys'), findsOneWidget);
      expect(find.byType(FilesPreviewPage), findsNothing);

      await tester.tap(find.text('Cancel'));
      await settle(tester);

      expect(source.count('readText'), 0);
      expect(source.count('download'), 0);
      expect(find.byType(FilesPreviewPage), findsNothing);
    });

    testWidgets('Continue shows the file and closing it deletes the copy', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.text('api_token.txt'));
      await settle(tester);
      await tester.tap(find.text('Continue'));
      await settle(tester);
      expect(find.text('KEY=1'), findsOneWidget);

      await tester.pageBack();
      await settle(tester);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );

      expect(find.byType(FilesPreviewPage), findsNothing);
    });

    testWidgets('Save says what was saved', (tester) async {
      await pump(tester);
      await tester.tap(find.text('export.zip'));
      await settle(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await settle(tester);

      expect(find.text('Saved export.zip.'), findsOneWidget);
      expect(actions.savedFiles.single.name, 'export.zip');
    });

    testWidgets('Share hands the staged file to the share sheet', (
      tester,
    ) async {
      final shared = <String>[];
      await pump(tester, share: (file, _) async => shared.add(file.path));
      await tester.tap(find.text('export.zip'));
      await settle(tester);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Share'));
      await settle(tester);

      expect(shared.single, endsWith('export.zip'));
    });
  });

  group('questions', () {
    testWidgets('a second secret question is asked again', (tester) async {
      await pump(tester);
      await tester.tap(find.text('api_token.txt'));
      await settle(tester);
      expect(find.textContaining('passwords or keys'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(find.textContaining('passwords or keys'), findsNothing);

      await tester.tap(find.text('deploy.pem'));
      await settle(tester);

      expect(find.textContaining('passwords or keys'), findsOneWidget);
    });

    testWidgets('the wide pane waits without a spinner behind the question', (
      tester,
    ) async {
      await pump(tester, size: const Size(1100, 800));
      await tester.tap(find.text('deploy.pem'));
      await settle(tester);

      expect(find.byType(FilesSpinner), findsNothing);
      expect(find.byType(FilePreviewHeader), findsOneWidget);
    });

    for (final (name, end) in <(String, Future<void> Function(WidgetTester))>[
      (
        'the chat changes',
        (tester) async {
          _stale = true;
          _changed.value++;
        },
      ),
      (
        'App Lock locks',
        (tester) async {
          _lock!.didChangeAppLifecycleState(AppLifecycleState.paused);
        },
      ),
    ]) {
      testWidgets('an open question goes with the page when $name', (
        tester,
      ) async {
        SharedPreferencesAsyncPlatform.instance =
            InMemorySharedPreferencesAsync.empty();
        _stale = false;
        _changed = ValueNotifier(0);
        _lock = AppLockController(authenticator: FakeDeviceAuthenticator());
        addTearDown(_lock!.dispose);
        await tester.runAsync(() async {
          await _lock!.load();
          await _lock!.setEnabled(true);
        });
        await pump(
          tester,
          closeWhen: _changed,
          shouldClose: () => _stale,
          lock: _lock,
        );
        await tester.tap(find.text('api_token.txt'));
        await settle(tester);
        expect(find.textContaining('passwords or keys'), findsOneWidget);

        await end(tester);
        await settle(tester);

        expect(find.textContaining('passwords or keys'), findsNothing);
        expect(find.byType(FilesScreen), findsNothing);
        expect(find.text('chat'), findsOneWidget);
      });
    }
  });

  group('wide', () {
    testWidgets('the preview sits beside the list', (tester) async {
      await pump(tester, size: const Size(1100, 800));
      expect(find.byType(FilesPreviewPane), findsOneWidget);
      expect(find.text('Select a file to preview it.'), findsOneWidget);

      await tester.tap(find.text('notes.txt'));
      await settle(tester);

      expect(find.byType(FilesPreviewPage), findsNothing);
      expect(find.text('hello from the notes'), findsOneWidget);
      expect(find.text('export.zip'), findsOneWidget);
    });

    testWidgets('a path-bar Up button goes to the parent', (tester) async {
      await pump(tester, size: const Size(1100, 800));
      await tester.tap(find.text('reports'));
      await settle(tester);
      expect(find.text('summary.txt'), findsOneWidget);

      await tester.tap(find.byTooltip('Up'));
      await settle(tester);

      expect(find.text('export.zip'), findsOneWidget);
    });
  });

  group('the app switcher', () {
    testWidgets('covers the preview while the app is inactive', (tester) async {
      await pump(tester, size: const Size(1100, 800));
      await tester.tap(find.text('notes.txt'));
      await settle(tester);
      expect(find.byKey(const Key('files-preview-cover')), findsNothing);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.byKey(const Key('files-preview-cover')), findsOneWidget);
      expect(find.byType(FilePreviewCover), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.byKey(const Key('files-preview-cover')), findsNothing);
      expect(find.text('hello from the notes'), findsOneWidget);
    });

    testWidgets('a desktop window that lost focus is not blanked', (
      tester,
    ) async {
      await pump(
        tester,
        size: const Size(1100, 800),
        platform: TargetPlatform.macOS,
      );
      await tester.tap(find.text('notes.txt'));
      await settle(tester);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();

      expect(find.byKey(const Key('files-preview-cover')), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });

    testWidgets('the phone preview page is covered too', (tester) async {
      await pump(tester);
      await tester.tap(find.text('notes.txt'));
      await settle(tester);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();

      expect(find.byKey(const Key('files-preview-cover')), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });
  });

  group('the page ends', () {
    testWidgets('when the chat or its profile changes', (tester) async {
      final changed = ValueNotifier(0);
      var stale = false;
      await pump(tester, closeWhen: changed, shouldClose: () => stale);
      expect(find.byType(FilesScreen), findsOneWidget);

      changed.value++;
      await settle(tester);
      expect(find.byType(FilesScreen), findsOneWidget, reason: 'same chat');

      stale = true;
      changed.value++;
      await settle(tester);
      expect(find.byType(FilesScreen), findsNothing);
    });

    testWidgets('and cancels what was running', (tester) async {
      final gate = Completer<void>();
      CancelToken? token;
      final hold = holds(gate);
      source.downloads['/srv/p/export.zip'] = (sink, t, large, progress) {
        token = t;
        return hold(sink, t, large, progress);
      };
      final changed = ValueNotifier(0);
      var stale = false;
      await pump(tester, closeWhen: changed, shouldClose: () => stale);
      await tester.tap(find.text('export.zip'));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await settle(tester);

      stale = true;
      changed.value++;
      await tester.pump();

      expect(token?.isCancelled, isTrue);
    });

    testWidgets('when App Lock locks', (tester) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final lock = AppLockController(authenticator: FakeDeviceAuthenticator());
      addTearDown(lock.dispose);
      await tester.runAsync(() async {
        await lock.load();
        await lock.setEnabled(true);
      });
      await pump(tester, lock: lock, size: const Size(1100, 800));
      await tester.tap(find.text('notes.txt'));
      await settle(tester);

      lock.didChangeAppLifecycleState(AppLifecycleState.paused);
      await settle(tester);

      expect(find.byType(FilesScreen), findsNothing);
      expect(find.text('hello from the notes'), findsNothing);
    });
  });

  group('macOS', () {
    testWidgets('rows are Quick Look targets and Space shows the file', (
      tester,
    ) async {
      source.downloads['/srv/p/notes.txt'] = writes([1, 2], length: 2);
      await pump(
        tester,
        size: const Size(1200, 800),
        platform: TargetPlatform.macOS,
      );
      expect(find.byType(QuickLookTarget), findsWidgets);

      await tester.tap(find.text('notes.txt'));
      await tester.pump(const Duration(milliseconds: 20));
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await settle(tester);

      expect(quickLook.shown, endsWith('notes.txt'));
    });

    testWidgets('command-up goes to the parent folder', (tester) async {
      await pump(
        tester,
        size: const Size(1200, 800),
        platform: TargetPlatform.macOS,
      );
      source.texts['/srv/p/reports/summary.txt'] = () =>
          ok(const FsTextFile(text: 'summary', byteSize: 7));
      await tester.tap(find.text('reports'));
      await settle(tester);
      await tester.tap(find.text('summary.txt'));
      await settle(tester);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
      await settle(tester);

      expect(find.text('export.zip'), findsOneWidget);
    });
  });
}

/// Real file IO and the frames after a tap, without `pumpAndSettle`, which a
/// spinner would keep from ever settling.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 15)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}
