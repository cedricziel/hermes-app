import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/skills/widgets/curator_run_confirmation.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

class _Calls {
  var cancels = 0;
  var runs = 0;
}

Widget _host(
  CuratorRunConfirmationModel model,
  _Calls calls, {
  TargetPlatform platform = TargetPlatform.iOS,
  Locale? locale,
  double scale = 1,
  bool dialog = false,
  Widget Function(Widget child)? wrap,
}) {
  final body = CuratorRunConfirmation(
    model: model,
    dialog: dialog,
    onCancel: () => calls.cancels++,
    onRun: () => calls.runs++,
  );
  return MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: buildHermesLightTheme(platform: platform),
    home: Scaffold(body: wrap == null ? body : wrap(body)),
  );
}

const _known = CuratorRunConfirmationModel(
  staleAfterDays: 14,
  archiveAfterDays: 30,
  pruneBuiltins: false,
  consolidate: false,
);

final _cancel = find.byKey(const ValueKey('curator-confirm-cancel'));
final _run = find.byKey(const ValueKey('curator-confirm-run'));

void main() {
  late _Calls calls;
  setUp(() => calls = _Calls());

  Future<void> pump(
    WidgetTester tester,
    CuratorRunConfirmationModel model, {
    TargetPlatform platform = TargetPlatform.iOS,
    Locale? locale,
    double scale = 1,
    bool dialog = false,
    Size size = const Size(800, 3000),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _host(
        model,
        calls,
        platform: platform,
        locale: locale,
        scale: scale,
        dialog: dialog,
      ),
    );
    await tester.pump();
  }

  group('items', () {
    testWidgets('known days, prune and consolidate off', (tester) async {
      await pump(tester, _known);
      expect(
        find.textContaining('Mark skills stale after 14 days'),
        findsOneWidget,
      );
      expect(find.textContaining('archive them after 30 days'), findsOneWidget);
      expect(find.textContaining('agent-made'), findsOneWidget);
      expect(find.textContaining('came with Hermes'), findsNothing);
      expect(find.textContaining('merge and rewrite'), findsNothing);
      expect(find.textContaining('rolled back'), findsNothing);
      expect(find.text('It archives unused skills only.'), findsOneWidget);
      expect(find.textContaining('are skipped'), findsOneWidget);
      expect(find.textContaining("This app can't undo a pass"), findsOneWidget);
    });

    testWidgets('prune on shows the built-in item', (tester) async {
      await pump(
        tester,
        const CuratorRunConfirmationModel(
          staleAfterDays: 14,
          archiveAfterDays: 30,
          pruneBuiltins: true,
          consolidate: false,
        ),
      );
      expect(
        find.text('Include skills that came with Hermes.'),
        findsOneWidget,
      );
      expect(find.textContaining('May include'), findsNothing);
    });

    testWidgets('consolidate on shows the merge item and the rollback note', (
      tester,
    ) async {
      await pump(
        tester,
        const CuratorRunConfirmationModel(
          staleAfterDays: 14,
          archiveAfterDays: 30,
          pruneBuiltins: false,
          consolidate: true,
        ),
      );
      expect(
        find.textContaining(
          'Merge and rewrite skills, and update scheduled tasks that use them.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('can only be rolled back'), findsOneWidget);
      expect(find.text('It archives unused skills only.'), findsNothing);
    });

    testWidgets('unknown config hedges both items', (tester) async {
      await pump(
        tester,
        const CuratorRunConfirmationModel(
          staleAfterDays: 14,
          archiveAfterDays: 30,
        ),
      );
      expect(
        find.text('May include skills that came with Hermes.'),
        findsOneWidget,
      );
      expect(find.textContaining('May also merge and rewrite'), findsOneWidget);
      expect(find.textContaining('can only be rolled back'), findsOneWidget);
      expect(find.text('It archives unused skills only.'), findsNothing);
    });

    testWidgets('unknown days say "the set number of days"', (tester) async {
      await pump(tester, const CuratorRunConfirmationModel());
      expect(find.textContaining('the set number of days'), findsOneWidget);
      expect(find.textContaining('14 days'), findsNothing);
    });

    testWidgets('one known threshold is not enough to quote numbers', (
      tester,
    ) async {
      await pump(tester, const CuratorRunConfirmationModel(staleAfterDays: 14));
      expect(find.textContaining('the set number of days'), findsOneWidget);
    });

    testWidgets('shows the restore command with its placeholders', (
      tester,
    ) async {
      await pump(tester, _known);
      expect(
        find.text('hermes curator restore <name> -p <profile>'),
        findsOneWidget,
      );
      expect(find.textContaining('Replace <name>'), findsOneWidget);
    });
  });

  group('buttons', () {
    testWidgets('Cancel comes first and has the focus', (tester) async {
      await pump(tester, _known, platform: TargetPlatform.android);
      expect(
        tester.getTopLeft(_cancel).dx,
        lessThan(tester.getTopLeft(_run).dx),
      );
      final focus = FocusManager.instance.primaryFocus!;
      expect(
        find.descendant(
          of: _cancel,
          matching: find.byWidget(focus.context!.widget),
        ),
        findsWidgets,
      );
    });

    testWidgets('Return on the focused Cancel cancels and sends nothing', (
      tester,
    ) async {
      await pump(tester, _known, platform: TargetPlatform.macOS, dialog: true);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(calls.cancels, 1);
      expect(calls.runs, 0);
    });

    testWidgets('Cancel calls onCancel only', (tester) async {
      await pump(tester, _known);
      await tester.tap(_cancel);
      expect(calls.cancels, 1);
      expect(calls.runs, 0);
    });

    testWidgets('Escape calls onCancel only', (tester) async {
      await pump(tester, _known, platform: TargetPlatform.macOS, dialog: true);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(calls.cancels, 1);
      expect(calls.runs, 0);
    });

    testWidgets('the system back action calls onCancel only', (tester) async {
      await pump(tester, _known, platform: TargetPlatform.android);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(calls.cancels, 1);
      expect(calls.runs, 0);
    });

    testWidgets('Run now calls onRun once', (tester) async {
      await pump(tester, _known);
      await tester.tap(_run);
      await tester.pump();
      expect(calls.runs, 1);
      expect(calls.cancels, 0);
    });

    testWidgets('a double tap on Run now reaches the caller once', (
      tester,
    ) async {
      await pump(tester, _known);
      await tester.tap(_run);
      await tester.tap(_run);
      await tester.pump();
      expect(calls.runs, 1);
      expect(calls.cancels, 0);
    });

    testWidgets('Cancel then Run in one frame only cancels', (tester) async {
      await pump(tester, _known);
      await tester.tap(_cancel);
      await tester.tap(_run);
      await tester.pump();
      expect(calls.cancels, 1);
      expect(calls.runs, 0);
    });

    testWidgets('Run then Cancel in one frame only runs', (tester) async {
      await pump(tester, _known);
      await tester.tap(_run);
      await tester.tap(_cancel);
      await tester.pump();
      expect(calls.runs, 1);
      expect(calls.cancels, 0);
    });

    testWidgets('Escape and then Run sends nothing', (tester) async {
      await pump(tester, _known, platform: TargetPlatform.macOS, dialog: true);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.tap(_run);
      await tester.pump();
      expect(calls.cancels, 1);
      expect(calls.runs, 0);
    });

    group('a caller that does not close the sheet', () {
      Future<void> open(WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 3000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: buildHermesLightTheme(platform: TargetPlatform.android),
            home: Builder(
              builder: (context) => TextButton(
                key: const ValueKey('open'),
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => CuratorRunConfirmation(
                    model: _known,
                    onCancel: () => calls.cancels++,
                    onRun: () => calls.runs++,
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        );
        await tester.tap(find.byKey(const ValueKey('open')));
        await tester.pumpAndSettle();
        expect(_run, findsOneWidget);
      }

      testWidgets('Run, then back closes it and calls nothing more', (
        tester,
      ) async {
        await open(tester);
        await tester.tap(_run);
        await tester.pumpAndSettle();
        expect(_run, findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(_run, findsNothing);
        expect(calls.runs, 1);
        expect(calls.cancels, 0);
      });

      testWidgets('back cancels once, and Run afterwards sends nothing', (
        tester,
      ) async {
        await open(tester);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(calls.cancels, 1);
        expect(_run, findsOneWidget);
        await tester.tap(_run);
        await tester.pumpAndSettle();
        expect(calls.runs, 0);
        expect(calls.cancels, 1);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(_run, findsNothing);
        expect(calls.cancels, 1);
      });

      testWidgets('Run, then Escape closes it and calls nothing more', (
        tester,
      ) async {
        await open(tester);
        await tester.tap(_run);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(_run, findsNothing);
        expect(calls.runs, 1);
        expect(calls.cancels, 0);
      });

      testWidgets('Run, then a tap on the barrier closes it', (tester) async {
        await open(tester);
        await tester.tap(_run);
        await tester.pumpAndSettle();
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        expect(_run, findsNothing);
        expect(calls.runs, 1);
        expect(calls.cancels, 0);
      });
    });

    group('a caller that closes the sheet itself', () {
      Future<void> open(WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 3000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: buildHermesLightTheme(platform: TargetPlatform.android),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  key: const ValueKey('open'),
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (sheet) => CuratorRunConfirmation(
                      model: _known,
                      onCancel: () {
                        calls.cancels++;
                        Navigator.pop(sheet);
                      },
                      onRun: () {
                        calls.runs++;
                        Navigator.pop(sheet);
                      },
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.byKey(const ValueKey('open')));
        await tester.pumpAndSettle();
        expect(_run, findsOneWidget);
      }

      testWidgets('back pops only the sheet and cancels once', (tester) async {
        await open(tester);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(_run, findsNothing);
        expect(find.byKey(const ValueKey('open')), findsOneWidget);
        expect(calls.cancels, 1);
        expect(calls.runs, 0);
      });
    });

    group('a decision made inside a callback', () {
      Future<void> pumpReentrant(
        WidgetTester tester, {
        required VoidCallback Function() onCancel,
        required VoidCallback Function() onRun,
      }) async {
        tester.view.physicalSize = const Size(800, 3000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: buildHermesLightTheme(platform: TargetPlatform.android),
            home: Scaffold(
              body: CuratorRunConfirmation(
                model: _known,
                onCancel: () {
                  calls.cancels++;
                  onCancel()();
                },
                onRun: () {
                  calls.runs++;
                  onRun()();
                },
              ),
            ),
          ),
        );
        await tester.pump();
      }

      void press(WidgetTester tester, Finder button) =>
          tester.widget<ButtonStyleButton>(button).onPressed!();

      testWidgets('Cancel pressed from inside onRun never reaches the caller', (
        tester,
      ) async {
        await pumpReentrant(
          tester,
          onCancel: () => () {},
          onRun: () =>
              () => press(tester, _cancel),
        );
        press(tester, _run);
        await tester.pump();
        expect(calls.runs, 1);
        expect(calls.cancels, 0);
      });

      testWidgets('Run pressed from inside onCancel never reaches the caller', (
        tester,
      ) async {
        await pumpReentrant(
          tester,
          onCancel: () =>
              () => press(tester, _run),
          onRun: () => () {},
        );
        press(tester, _cancel);
        await tester.pump();
        expect(calls.cancels, 1);
        expect(calls.runs, 0);
      });

      testWidgets('Run pressed from inside onRun calls the caller once', (
        tester,
      ) async {
        await pumpReentrant(
          tester,
          onCancel: () => () {},
          onRun: () =>
              () => press(tester, _run),
        );
        press(tester, _run);
        await tester.pump();
        expect(calls.runs, 1);
        expect(calls.cancels, 0);
      });
    });

    testWidgets(
      'a decided sheet closes from the next frame on: back in the frame of '
      'Run is swallowed',
      (tester) async {
        tester.view.physicalSize = const Size(800, 3000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: buildHermesLightTheme(platform: TargetPlatform.android),
            home: Builder(
              builder: (context) => TextButton(
                key: const ValueKey('open'),
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => CuratorRunConfirmation(
                    model: _known,
                    onCancel: () => calls.cancels++,
                    onRun: () => calls.runs++,
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        );
        await tester.tap(find.byKey(const ValueKey('open')));
        await tester.pumpAndSettle();

        // No pump between Run and back: the route still refuses to pop.
        await tester.tap(_run);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(_run, findsOneWidget);
        expect(calls.runs, 1);
        expect(calls.cancels, 0);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(_run, findsNothing);
        expect(calls.runs, 1);
        expect(calls.cancels, 0);
      },
    );

    for (final (platform, minHeight, name) in [
      (TargetPlatform.iOS, 44.0, 'iOS 44 pt'),
      (TargetPlatform.android, 48.0, 'Android 48 dp'),
      (TargetPlatform.macOS, 28.0, 'Mac 28 pt'),
    ]) {
      testWidgets('touch targets are at least $name', (tester) async {
        await pump(
          tester,
          _known,
          platform: platform,
          dialog: platform == TargetPlatform.macOS,
        );
        for (final button in [_cancel, _run]) {
          final size = tester.getSize(button);
          expect(size.height, greaterThanOrEqualTo(minHeight));
          if (platform == TargetPlatform.macOS) {
            expect(size.height, lessThan(36));
          }
        }
      });
    }

    testWidgets('Cancel is never filled, Run now is not red', (tester) async {
      for (final platform in TargetPlatform.values.where(
        (p) => p == TargetPlatform.iOS || p == TargetPlatform.android,
      )) {
        await pump(tester, _known, platform: platform);
        expect(find.byType(FilledButton), findsNothing);
        final run = tester.widget<ButtonStyleButton>(_run);
        final color = run.style!.foregroundColor!.resolve({});
        expect(color, isNot(Theme.of(tester.element(_run)).colorScheme.error));
        final cancel = tester.widget<ButtonStyleButton>(_cancel);
        expect(cancel.style!.backgroundColor?.resolve({}), isNull);
        expect(
          cancel.style!.textStyle!.resolve({})!.fontWeight,
          FontWeight.w700,
        );
      }
    });

    testWidgets('Apple Cancel is plain text, Run now outlined', (tester) async {
      await pump(tester, _known);
      expect(tester.widget(_cancel), isA<TextButton>());
      expect(tester.widget(_run), isA<OutlinedButton>());
    });
  });

  group('stacking', () {
    testWidgets('an Apple phone stacks, Cancel on top', (tester) async {
      await pump(tester, _known);
      expect(
        tester.getTopLeft(_cancel).dy,
        lessThan(tester.getTopLeft(_run).dy),
      );
      expect(tester.getTopLeft(_cancel).dx, tester.getTopLeft(_run).dx);
    });

    testWidgets('an iPad dialog puts them side by side', (tester) async {
      await pump(tester, _known, dialog: true);
      expect(tester.getTopLeft(_cancel).dy, tester.getTopLeft(_run).dy);
      expect(
        tester.getTopLeft(_cancel).dx,
        lessThan(tester.getTopLeft(_run).dx),
      );
    });

    testWidgets('Android is side by side, Cancel left', (tester) async {
      await pump(tester, _known, platform: TargetPlatform.android);
      expect(tester.getTopLeft(_cancel).dy, tester.getTopLeft(_run).dy);
      expect(
        tester.getTopLeft(_cancel).dx,
        lessThan(tester.getTopLeft(_run).dx),
      );
    });

    for (final platform in [TargetPlatform.android, TargetPlatform.macOS]) {
      testWidgets('exactly 1.5x text stacks on $platform', (tester) async {
        await pump(
          tester,
          _known,
          platform: platform,
          scale: 1.5,
          dialog: platform == TargetPlatform.macOS,
        );
        expect(tester.getTopLeft(_cancel).dx, tester.getTopLeft(_run).dx);
        expect(
          tester.getTopLeft(_cancel).dy,
          lessThan(tester.getTopLeft(_run).dy),
        );
      });

      testWidgets('1.4x text is still side by side on $platform', (
        tester,
      ) async {
        await pump(
          tester,
          _known,
          platform: platform,
          scale: 1.4,
          dialog: platform == TargetPlatform.macOS,
        );
        expect(tester.getTopLeft(_cancel).dy, tester.getTopLeft(_run).dy);
        expect(
          tester.getTopLeft(_cancel).dx,
          lessThan(tester.getTopLeft(_run).dx),
        );
      });

      testWidgets('1.6x text stacks on $platform', (tester) async {
        await pump(
          tester,
          _known,
          platform: platform,
          scale: 1.6,
          dialog: platform == TargetPlatform.macOS,
        );
        expect(tester.getTopLeft(_cancel).dx, tester.getTopLeft(_run).dx);
        expect(
          tester.getTopLeft(_cancel).dy,
          lessThan(tester.getTopLeft(_run).dy),
        );
      });
    }

    for (final platform in [
      TargetPlatform.iOS,
      TargetPlatform.android,
      TargetPlatform.macOS,
    ]) {
      testWidgets('2x text stacks on $platform', (tester) async {
        await pump(
          tester,
          _known,
          platform: platform,
          scale: 2,
          dialog: platform == TargetPlatform.macOS,
        );
        expect(tester.getTopLeft(_cancel).dx, tester.getTopLeft(_run).dx);
        expect(
          tester.getTopLeft(_cancel).dy,
          lessThan(tester.getTopLeft(_run).dy),
        );
      });
    }
  });

  testWidgets(
    'scrolls with pinned buttons in German at the largest text on a small phone',
    (tester) async {
      await pump(
        tester,
        const CuratorRunConfirmationModel(
          staleAfterDays: 14,
          archiveAfterDays: 30,
        ),
        locale: const Locale('de'),
        scale: 3.1,
        size: const Size(320, 568),
      );
      expect(tester.takeException(), isNull);
      final runBottom = tester.getBottomLeft(_run).dy;
      expect(runBottom, lessThanOrEqualTo(568));
      // The command sits below the fold until the body is scrolled.
      final command = find.text('hermes curator restore <name> -p <profile>');
      expect(tester.getTopLeft(command).dy, greaterThan(568));
      final scrollable = find.descendant(
        of: find.byType(CuratorRunConfirmation),
        matching: find.byType(Scrollable),
      );
      final before = tester.getTopLeft(_run);
      await tester.scrollUntilVisible(
        command,
        400,
        scrollable: scrollable.first,
      );
      expect(tester.getTopLeft(_run), before);
      expect(tester.getBottomLeft(command).dy, lessThan(runBottom));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'button labels keep scaling past 2x and the body keeps a quarter of the '
    'window at 3.1x in German on a small iPhone',
    (tester) async {
      await pump(
        tester,
        const CuratorRunConfirmationModel(
          staleAfterDays: 14,
          archiveAfterDays: 30,
        ),
        locale: const Locale('de'),
        scale: 3.1,
        size: const Size(320, 568),
      );
      final viewport = tester.getSize(find.byType(SingleChildScrollView).first);
      // At least 25 percent of the window (measured with the test font; about
      // 48 percent with the real font).
      expect(viewport.height, greaterThanOrEqualTo(568 * 0.25));
      final label = tester.widget<Text>(
        find.descendant(of: _run, matching: find.byType(Text)),
      );
      expect(
        MediaQuery.textScalerOf(tester.element(find.byWidget(label))).scale(14),
        closeTo(14 * 3.1, 0.01),
      );
    },
  );

  testWidgets('Copy puts exactly the typed command on the clipboard', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pump(tester, _known);
    await tester.tap(find.text('Copy'));
    await tester.pump();
    expect(copied, 'hermes curator restore <name> -p <profile>');
    expect(calls.runs, 0);
    expect(calls.cancels, 0);
    await tester.pump(const Duration(seconds: 3));
  });
}
