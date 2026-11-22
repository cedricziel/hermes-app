import 'package:flutter/cupertino.dart' show CupertinoSlidingSegmentedControl;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart'
    show ComposerHeightNotifier;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' as mui;
import 'package:gpt_markdown/gpt_markdown.dart' show CodeBlockStyle;
import 'package:hermes_app/src/bot_screen/input/screen_gesture_layer.dart';
import 'package:hermes_app/src/bot_screen/widgets/bot_screen_key_bar.dart';
import 'package:hermes_app/src/chat/widgets/new_chat_fab.dart';
import 'package:hermes_app/src/chat/widgets/scroll_to_latest_button.dart';
import 'package:hermes_app/src/chat/widgets/tool_value_view.dart';
import 'package:hermes_app/src/kanban/widgets/new_task_fab.dart';
import 'package:hermes_app/src/schedules/schedule_picker.dart';
import 'package:hermes_app/src/schedules/schedule_spec.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/theme/focus_ring.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/theme/material_ui_bridge.dart';
import 'package:hermes_app/src/voice/widgets/voice_orb.dart';
import 'package:hermes_app/src/widgets/adaptive_popup_menu_button.dart';
import 'package:hermes_app/src/widgets/adaptive_segmented_control.dart';
import 'package:hermes_app/src/widgets/composer_selector_chip.dart';
import 'package:hermes_app/src/widgets/disclosure_tile.dart';
import 'package:hermes_app/src/widgets/hermes_code_block.dart';
import 'package:hermes_app/src/widgets/row_actions.dart';
import 'package:hermes_app/src/widgets/whats_the_difference_link.dart';
import 'package:provider/provider.dart';

/// What [FocusRing] and [HostFocusRing] paint.
final _ringPainter = find.byWidgetPredicate(
  (w) => w is CustomPaint && w.foregroundPainter is FocusRingPainter,
);

FocusRingPainter _painter(WidgetTester tester) =>
    tester.widget<CustomPaint>(_ringPainter.first).foregroundPainter!
        as FocusRingPainter;

Widget _scoped(BuildContext context, Widget? child) =>
    AppThemeScopes(child: child!);

Future<void> _pump(WidgetTester tester, ThemeData theme, Widget body) =>
    tester.pumpWidget(
      MaterialApp(
        theme: theme,
        builder: _scoped,
        home: Scaffold(
          body: Align(alignment: Alignment.topLeft, child: body),
        ),
      ),
    );

void _strategy(FocusHighlightStrategy strategy) {
  FocusManager.instance.highlightStrategy = strategy;
  addTearDown(
    () => FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.automatic,
  );
}

/// The focus node of the control that [inside] is, or is in: the first one in
/// [inside]'s subtree, else the nearest one above it.
FocusNode _nodeOf(WidgetTester tester, Finder inside) {
  final target = tester.element(inside.first);
  for (final node in FocusManager.instance.rootScope.traversalDescendants) {
    var within = false;
    node.context?.visitAncestorElements((e) {
      within = identical(e, target);
      return !within;
    });
    if (within) return node;
  }
  return Focus.of(target);
}

/// Moves focus to the control [inside] is, as the Tab key does.
Future<void> _focus(WidgetTester tester, Finder inside) async {
  _nodeOf(tester, inside).requestFocus();
  await tester.pumpAndSettle();
}

/// A mouse press and release at the top left corner, off every control.
Future<void> _pointerPress(WidgetTester tester) async {
  final press = await tester.startGesture(
    const Offset(1, 1),
    kind: PointerDeviceKind.mouse,
  );
  await press.up();
  await tester.pumpAndSettle();
}

double _contrast(Color a, Color b) {
  final (la, lb) = (a.computeLuminance(), b.computeLuminance());
  return (la > lb ? la + .05 : lb + .05) / (la > lb ? lb + .05 : la + .05);
}

void main() {
  setUp(resetFocusRingInput);

  for (final (name, theme) in [
    ('light', buildHermesLightTheme()),
    ('dark', buildHermesDarkTheme()),
  ]) {
    final link = theme.extension<HermesChatColors>()!.link;
    ThemeData on(TargetPlatform platform) => theme.copyWith(platform: platform);

    /// The three things every control must do: a keyboard ring in the link
    /// colour (2 px wide), none after a pointer press (back with the next
    /// key), none in touch mode.
    void ringsOnKeyboardOnly(
      String control, {
      required ThemeData theme,
      required Widget Function() build,
      required Finder inside,
      double? inset,
      double? radius,
    }) {
      testWidgets('$control ($name): a 2 px link-colour ring with the '
          'keyboard, none after a pointer press', (tester) async {
        _strategy(FocusHighlightStrategy.alwaysTraditional);
        await _pump(tester, theme, build());
        expect(_ringPainter, findsNothing);

        await _focus(tester, inside);
        expect(_ringPainter, findsOneWidget);
        final painter = _painter(tester);
        expect(painter.color, link);
        expect(painter.width, 2);
        if (inset != null) expect(painter.inset, inset);
        if (radius != null) expect(painter.radius, radius);

        await _pointerPress(tester);
        expect(_ringPainter, findsNothing, reason: 'a pointer press hides it');

        await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pumpAndSettle();
        expect(_ringPainter, findsOneWidget, reason: 'the next key shows it');

        _nodeOf(tester, inside).unfocus();
        await tester.pumpAndSettle();
        expect(_ringPainter, findsNothing, reason: 'none when not focused');
      });

      testWidgets('$control ($name): no ring for touch focus', (tester) async {
        _strategy(FocusHighlightStrategy.alwaysTouch);
        await _pump(tester, theme, build());
        await _focus(tester, inside);
        expect(_nodeOf(tester, inside).hasFocus, isTrue);
        expect(_ringPainter, findsNothing);
      });
    }

    group('segmented controls, $name', () {
      Widget segments() => AdaptiveSegmentedControl<int>(
        value: 0,
        segments: const {0: 'Chats', 1: 'Files', 2: 'Tasks'},
        onChanged: (_) {},
      );

      ringsOnKeyboardOnly(
        'Android SegmentedButton segment',
        theme: on(TargetPlatform.android),
        build: segments,
        inside: find.text('Files'),
        radius: 12,
        inset: kFocusRingOffset,
      );

      ringsOnKeyboardOnly(
        'iOS sliding control',
        theme: on(TargetPlatform.iOS),
        build: segments,
        inside: find.byType(CupertinoSlidingSegmentedControl<int>),
        // 2 px outside the track (radius 9): 4 px out, the outer radius 13.
        inset: -4,
        radius: 13,
      );

      testWidgets('the Android ring is on the focused segment, not the whole '
          'control, and stays inside the control\'s 28 dp', (tester) async {
        _strategy(FocusHighlightStrategy.alwaysTraditional);
        await _pump(tester, on(TargetPlatform.android), segments());
        await _focus(tester, find.text('Files'));
        final painter = _painter(tester) as HostFocusRingPainter;
        final host = painter.host.renderObject! as RenderBox;
        final segment = tester.getRect(find.byType(TextButton).at(1));
        expect(host.localToGlobal(Offset.zero) & host.size, segment);
        expect(painter.host.widget, isA<TextButton>());
        expect(painter.maxHeight, lessThanOrEqualTo(28));
      });
    });

    group('tap targets, $name', () {
      ringsOnKeyboardOnly(
        'model pill',
        theme: theme,
        build: () => ComposerSelectorChip(
          label: 'claude-sonnet · high',
          onPressed: () {},
        ),
        inside: find.text('claude-sonnet · high'),
        // Inside the pill (radius 20) by 2 px.
        inset: kFocusRingOffset,
        radius: 18,
      );

      testWidgets('the model pill\'s Retry button keeps the button ring and '
          'the pill ring does not show for it', (tester) async {
        _strategy(FocusHighlightStrategy.alwaysTraditional);
        await _pump(
          tester,
          theme,
          ComposerSelectorChip(
            label: 'claude-sonnet',
            onPressed: () {},
            actionLabel: 'Retry',
            onAction: () {},
          ),
        );
        await _focus(tester, find.text('Retry'));
        expect(_ringPainter, findsNothing);
      });

      ringsOnKeyboardOnly(
        'weekday toggle',
        theme: theme,
        build: () => SchedulePicker(
          spec: const WeeklySpec({1, 2, 3}, 9, 0),
          now: DateTime(2026, 11, 22),
          onChanged: (_) {},
        ),
        inside: find.text('Tue'),
        // 2 px outside the 32 dp pill.
        inset: -4,
        radius: 20,
      );

      ringsOnKeyboardOnly(
        'tool value copy button',
        theme: theme,
        build: () =>
            ToolValueCopyButton(label: 'Copy result', onPressed: () {}),
        inside: find.byIcon(Icons.content_copy),
        inset: -4,
      );

      ringsOnKeyboardOnly(
        'Bot Screen key',
        theme: theme,
        build: () => BotScreenKeyBar(
          mode: ScreenGestureMode.touch,
          ctrl: false,
          alt: false,
          keyboardOpen: false,
          onMode: (_) {},
          onEscape: () {},
          onTab: () {},
          onLeft: () {},
          onRight: () {},
          onToggleCtrl: () {},
          onToggleAlt: () {},
          onToggleKeyboard: () {},
          onPaste: () {},
        ),
        inside: find.text('Esc'),
        inset: -4,
        radius: 14,
      );

      ringsOnKeyboardOnly(
        'voice orb',
        theme: theme,
        build: () => VoiceOrb(state: VoiceOrbState.speaking, onTap: () {}),
        inside: find.byType(InkResponse),
        inset: -4,
        radius: 56 + 4,
      );

      ringsOnKeyboardOnly(
        'link',
        theme: theme,
        build: () => WhatsTheDifferenceLink(onTap: () {}),
        inside: find.byType(InkWell),
        inset: -4,
        radius: 8,
      );

      ringsOnKeyboardOnly(
        'code block copy button',
        theme: theme,
        build: () => HermesCodeBlock(
          name: 'dart',
          codes: 'void main() {}\n',
          style: const CodeBlockStyle(),
        ),
        inside: find.byType(mui.InkWell),
        inset: -4,
      );
    });

    group('floating buttons, $name', () {
      ringsOnKeyboardOnly(
        'new chat button',
        theme: on(TargetPlatform.android),
        build: () => NewChatFab(onPressed: () {}),
        inside: find.byType(FloatingActionButton),
        // The button's 14 dp radius, 2 px out.
        inset: -4,
        radius: kHermesRadius + 4,
      );

      ringsOnKeyboardOnly(
        'new task button',
        theme: on(TargetPlatform.android),
        build: () => NewTaskFab(onPressed: () {}),
        inside: find.byType(FloatingActionButton),
        inset: -4,
        radius: 32,
      );

      ringsOnKeyboardOnly(
        'scroll to latest button',
        theme: on(TargetPlatform.android),
        build: () => ChangeNotifierProvider(
          create: (_) => ComposerHeightNotifier(),
          child: Stack(
            children: [
              SizedBox(
                width: 200,
                height: 200,
                child: Stack(
                  children: [
                    ScrollToLatestButton(
                      animation: const AlwaysStoppedAnimation(1),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        inside: find.byType(FloatingActionButton),
        inset: -4,
        radius: 24,
      );
    });

    group('disclosure tiles, $name', () {
      Widget tile({bool open = false}) => DisclosureTile(
        initiallyExpanded: open,
        title: const Text('Tool output'),
        children: [TextButton(onPressed: () {}, child: const Text('Copy'))],
      );

      ringsOnKeyboardOnly(
        'closed DisclosureTile',
        theme: theme,
        build: tile,
        inside: find.text('Tool output'),
        inset: kFocusRingOffset,
      );

      ringsOnKeyboardOnly(
        'open DisclosureTile',
        theme: theme,
        build: () => tile(open: true),
        inside: find.text('Tool output'),
        inset: kFocusRingOffset,
      );

      testWidgets('the ring is on the header row only, not on the tile with '
          'its children, and none for a focused child', (tester) async {
        _strategy(FocusHighlightStrategy.alwaysTraditional);
        await _pump(
          tester,
          theme,
          SizedBox(width: 320, child: tile(open: true)),
        );
        await _focus(tester, find.text('Tool output'));
        final painter = _painter(tester) as HostFocusRingPainter;
        final header = tester.getRect(find.byType(ListTile));
        final host = painter.host.renderObject! as RenderBox;
        expect(host.localToGlobal(Offset.zero) & host.size, header);
        expect(painter.host.widget, isA<ListTile>());
        expect(
          header.height,
          lessThan(tester.getSize(find.byType(DisclosureTile)).height),
        );

        await _focus(tester, find.text('Copy'));
        expect(
          _ringPainter.evaluate().where(
            (e) =>
                ((e.widget as CustomPaint).foregroundPainter)
                    is HostFocusRingPainter,
          ),
          isEmpty,
        );
      });

      testWidgets('a disabled tile takes no focus and shows no ring', (
        tester,
      ) async {
        _strategy(FocusHighlightStrategy.alwaysTraditional);
        await _pump(
          tester,
          theme,
          const DisclosureTile(
            enabled: false,
            title: Text('Locked'),
            children: [Text('x')],
          ),
        );
        expect(_ringPainter, findsNothing);
      });
    });

    group('Mac menus, $name', () {
      final mac = on(TargetPlatform.macOS);

      Future<void> openMenu(
        WidgetTester tester,
        List<PopupMenuEntry<int>> items,
      ) async {
        await _pump(
          tester,
          mac,
          AdaptivePopupMenuButton<int>(
            tooltip: 'Menu',
            onSelected: (_) {},
            itemBuilder: (_) => items,
          ),
        );
        await tester.tap(find.byType(IconButton));
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        // The keyboard moved focus; the press that opened the menu no longer
        // counts.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
      }

      testWidgets('a focused Mac menu row draws the ring 2 px inside its fill, '
          'radius 4; none after a pointer press', (tester) async {
        _strategy(FocusHighlightStrategy.alwaysTraditional);
        await openMenu(tester, const [
          AdaptiveMenuItem<int>(value: 1, child: Text('Rename')),
          AdaptiveMenuItem<int>(value: 2, child: Text('Duplicate')),
        ]);
        expect(_ringPainter, findsOneWidget);
        final painter = _painter(tester);
        // On the primary fill the link colour is 1.68:1 (dark), so the ring is
        // onPrimary, which clears 3:1 against it.
        expect(painter.color, theme.colorScheme.onPrimary);
        expect(
          _contrast(painter.color, theme.colorScheme.primary),
          greaterThanOrEqualTo(3),
        );
        expect(painter.radius, 4);
        expect(painter.inset, kFocusRingOffset);
        final row = tester.getRect(find.byType(MacMenuRow).last);
        expect(tester.getRect(_ringPainter), row);

        final press = await tester.startGesture(
          const Offset(1, 1),
          kind: PointerDeviceKind.mouse,
        );
        await tester.pumpAndSettle();
        expect(_ringPainter, findsNothing);
        await press.cancel();
      });

      testWidgets('an unfocused Mac menu row has no ring', (tester) async {
        _strategy(FocusHighlightStrategy.alwaysTraditional);
        await openMenu(tester, const [
          AdaptiveMenuItem<int>(value: 1, child: Text('Rename')),
          AdaptiveMenuItem<int>(value: 2, child: Text('Duplicate')),
        ]);
        // Only the focused row of the two has a ring.
        expect(_ringPainter, findsOneWidget);
      });

      testWidgets(
        'a focused checked item in a Mac menu draws the ring, with no '
        'hover fill; none after a pointer press',
        (tester) async {
          _strategy(FocusHighlightStrategy.alwaysTraditional);
          await openMenu(tester, const [
            CheckedPopupMenuItem<int>(
              value: 1,
              checked: true,
              child: Text('Newest'),
            ),
            CheckedPopupMenuItem<int>(value: 2, child: Text('Oldest')),
          ]);
          expect(_ringPainter, findsOneWidget);
          expect(_painter(tester).color, link);
          expect(_painter(tester).radius, 4);
          expect(
            find.byWidgetPredicate(
              (w) => w is CustomPaint && w.painter is FocusRingFillPainter,
            ),
            findsOneWidget,
          );
          expect(
            tester
                .widget<CustomPaint>(
                  find.byWidgetPredicate(
                    (w) =>
                        w is CustomPaint && w.painter is FocusRingFillPainter,
                  ),
                )
                .painter,
            isA<FocusRingFillPainter>().having(
              (p) => p.color.a,
              'the Mac theme clears the hover colour, so the fill is clear',
              0,
            ),
          );
          final press = await tester.startGesture(
            const Offset(1, 1),
            kind: PointerDeviceKind.mouse,
          );
          await tester.pumpAndSettle();
          expect(_ringPainter, findsNothing);
          await press.cancel();
        },
      );

      testWidgets('the Mac row context menu gives its items the ring', (
        tester,
      ) async {
        _strategy(FocusHighlightStrategy.alwaysTraditional);
        await _pump(
          tester,
          mac,
          SizedBox(
            width: 200,
            height: 48,
            child: RowActions(
              title: 'Job',
              actions: [
                RowAction(
                  label: 'Run now',
                  icon: AppIcons.play,
                  onPressed: () {},
                ),
                RowAction(
                  label: 'Pause',
                  icon: AppIcons.play,
                  onPressed: () {},
                ),
              ],
              child: const ListTile(title: Text('Job')),
            ),
          ),
        );
        final click = await tester.startGesture(
          tester.getCenter(find.text('Job')),
          kind: PointerDeviceKind.mouse,
          buttons: kSecondaryMouseButton,
        );
        await click.up();
        await tester.pumpAndSettle();
        expect(find.byType(FocusRingMenuItem<RowAction>), findsNWidgets(2));
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(_ringPainter, findsOneWidget);
        expect(_painter(tester).color, link);
      });
    });
  }

  test('FocusRing.outside is the control radius plus the offset and width, '
      'and the ring starts offset px out', () {
    const ring = FocusRing.outside(radius: 10, child: SizedBox());
    expect(ring.radius, 10 + kFocusRingOffset + kFocusRingWidth);
    expect(ring.inset, -(kFocusRingOffset + kFocusRingWidth));
    expect(ring.fill, isNull);
  });

  testWidgets('FocusRing.outside paints past the child\'s bounds, 2 px out', (
    tester,
  ) async {
    _strategy(FocusHighlightStrategy.alwaysTraditional);
    final node = FocusNode();
    addTearDown(node.dispose);
    await _pump(
      tester,
      buildHermesLightTheme(),
      Padding(
        padding: const EdgeInsets.all(20),
        child: FocusRing.outside(
          radius: 8,
          child: Focus(
            focusNode: node,
            child: const SizedBox(width: 100, height: 40),
          ),
        ),
      ),
    );
    node.requestFocus();
    await tester.pumpAndSettle();
    final box = tester.renderObject<RenderBox>(_ringPainter);
    final painter = _painter(tester);
    // Stroke centre 3 px out, 2 px wide: the band is 2 to 4 px outside.
    final rect = (Offset.zero & box.size).deflate(painter.inset + 1);
    expect(rect, (Offset.zero & box.size).inflate(3));
    expect(
      box,
      paints..rrect(
        rrect: RRect.fromRectAndRadius(rect, const Radius.circular(11)),
        color: buildHermesLightTheme().extension<HermesChatColors>()!.link,
        strokeWidth: 2,
      ),
    );
  });

  testWidgets('a tap target is not smaller because of the ring', (
    tester,
  ) async {
    await _pump(
      tester,
      buildHermesLightTheme().copyWith(platform: TargetPlatform.android),
      NewChatFab(onPressed: () {}),
    );
    expect(
      tester.getSize(find.byType(FloatingActionButton)),
      const Size(56, 56),
    );
    expect(
      tester.getSize(find.byType(FocusRing)),
      const Size(56, 56),
      reason: 'the ring paints past the bounds and takes no layout room',
    );
  });
}
