import 'package:flutter/cupertino.dart' show CupertinoSlidingSegmentedControl;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart'
    show ComposerHeightNotifier;
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart' show CodeBlockStyle;
import 'package:hermes_app/src/bot_screen/input/screen_gesture_layer.dart';
import 'package:hermes_app/src/bot_screen/widgets/bot_screen_key_bar.dart';
import 'package:hermes_app/src/chat/attachments/attachment_source.dart';
import 'package:hermes_app/src/chat/attachments/widgets/attach_menu.dart';
import 'package:hermes_app/src/chat/widgets/new_chat_fab.dart';
import 'package:hermes_app/src/chat/widgets/scroll_to_latest_button.dart';
import 'package:hermes_app/src/chat/widgets/tool_value_view.dart';
import 'package:hermes_app/src/kanban/widgets/new_task_fab.dart';
import 'package:hermes_app/src/schedules/schedule_picker.dart';
import 'package:hermes_app/src/schedules/schedule_spec.dart';
import 'package:hermes_app/src/theme/focus_ring.dart';
import 'package:hermes_app/src/theme/material_ui_bridge.dart';
import 'package:hermes_app/src/voice/widgets/voice_orb.dart';
import 'package:hermes_app/src/widgets/adaptive_popup_menu_button.dart';
import 'package:hermes_app/src/widgets/adaptive_segmented_control.dart';
import 'package:hermes_app/src/widgets/hermes_code_block.dart';
import 'package:hermes_app/src/widgets/whats_the_difference_link.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:material_ui/material_ui.dart' as mui;
import 'package:provider/provider.dart';

/// The drawn geometry of the keyboard focus ring against what is painted: the
/// ring follows the visible shape, not the layout box round it. An outside
/// ring's inner edge is 2 px outside the shape on every side, its corner radius
/// is the shape's plus 2; an inside ring's outer edge is 2 px inside it.

final _ringFinder = find.byWidgetPredicate(
  (w) => w is CustomPaint && w.foregroundPainter is FocusRingPainter,
);

/// A canvas that keeps the one rounded rectangle drawn on it.
class _Recorder implements Canvas {
  RRect? rrect;

  @override
  void drawRRect(RRect rrect, Paint paint) => this.rrect = rrect;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// The band of the ring drawn by [FocusRing], in global coordinates.
Path _ringBand(WidgetTester tester, [Finder? ring]) {
  final finder = ring ?? _ringFinder;
  expect(finder, findsOneWidget);
  final painter =
      tester.widget<CustomPaint>(finder).foregroundPainter! as FocusRingPainter;
  final box = tester.renderObject<RenderBox>(finder);
  final recorder = _Recorder();
  painter.paint(recorder, box.size);
  final center = recorder.rrect!.shift(box.localToGlobal(Offset.zero));
  final half = painter.width / 2;
  RRect grow(double by) => RRect.fromRectAndRadius(
    center.outerRect.inflate(by),
    Radius.circular(center.tlRadiusX + by),
  );
  return Path.combine(
    PathOperation.difference,
    Path()..addRRect(grow(half)),
    Path()..addRRect(grow(-half)),
  );
}

/// The band a [FocusRingBorder] paints on [material]'s shape.
Path _borderBand(WidgetTester tester, Finder material) {
  final box = tester.renderObject<RenderBox>(material);
  final shape = tester.widget<Material>(material).shape;
  expect(shape, isA<FocusRingBorder>());
  final rect = box.localToGlobal(Offset.zero) & box.size;
  return (shape! as FocusRingBorder).ringPath(rect);
}

/// The painted shape of [finder]: its rect and its corner radius.
(Rect, double) _painted(WidgetTester tester, Finder finder) {
  final rect = tester.getRect(finder);
  final widget = tester.widget(finder);
  double fromShape(ShapeBorder? shape) => switch (shape) {
    RoundedRectangleBorder(:final borderRadius) =>
      (borderRadius as BorderRadius).topLeft.x,
    StadiumBorder() || CircleBorder() => rect.shortestSide / 2,
    _ => 0,
  };
  final radius = switch (widget) {
    Material(:final borderRadius?) => (borderRadius as BorderRadius).topLeft.x,
    Material(:final shape) => fromShape(shape),
    InkWell(:final borderRadius?) => borderRadius.topLeft.x,
    InkResponse(:final customBorder) => fromShape(customBorder),
    DecoratedBox(:final decoration) => switch (decoration) {
      BoxDecoration(shape: BoxShape.circle) => rect.shortestSide / 2,
      BoxDecoration(:final borderRadius?) =>
        (borderRadius as BorderRadius).topLeft.x,
      ShapeDecoration(:final shape) =>
        shape is RoundedSuperellipseBorder
            ? (shape.borderRadius as BorderRadius).topLeft.x
            : fromShape(shape),
      _ => 0.0,
    },
    _ => 0.0,
  };
  return (rect, radius);
}

/// Points [d] px out (positive) or in (negative) of [shape] at the middle of
/// each side and, for a rounded corner, along each corner's diagonal.
List<Offset> _probes(Rect shape, double radius, double d) {
  final c = shape.center;
  final out = [
    Offset(c.dx, shape.top - d),
    Offset(c.dx, shape.bottom + d),
    Offset(shape.left - d, c.dy),
    Offset(shape.right + d, c.dy),
  ];
  if (radius > 1) {
    const k = 0.7071067811865476;
    final r = radius;
    final centres = [
      (Offset(shape.left + r, shape.top + r), const Offset(-k, -k)),
      (Offset(shape.right - r, shape.top + r), const Offset(k, -k)),
      (Offset(shape.left + r, shape.bottom - r), const Offset(-k, k)),
      (Offset(shape.right - r, shape.bottom - r), const Offset(k, k)),
    ];
    for (final (centre, u) in centres) {
      out.add(centre + u * (r + d));
    }
  }
  return out;
}

/// The ring hugs [shape]: its band covers 2.6 to 3.4 px outside it and
/// nothing at 1.4 or 4.6 px, on every side and every corner.
void expectRingHugs(Path band, (Rect, double) shape, {String? reason}) {
  final (rect, radius) = shape;
  for (final d in [2.6, 3.0, 3.4]) {
    for (final p in _probes(rect, radius, d)) {
      expect(band.contains(p), isTrue, reason: '$reason: $d px out at $p');
    }
  }
  for (final d in [1.4, 4.6]) {
    for (final p in _probes(rect, radius, d)) {
      expect(band.contains(p), isFalse, reason: '$reason: $d px out at $p');
    }
  }
}

/// An inside ring: its band covers 2.6 to 3.4 px inside [clip] and nothing at
/// 1.4 or 4.6 px.
void expectRingInside(Path band, Rect clip, {double radius = 0, String? why}) {
  for (final d in [2.6, 3.0, 3.4]) {
    for (final p in _probes(clip, radius, -d)) {
      expect(band.contains(p), isTrue, reason: '$why: $d px in at $p');
    }
  }
  for (final d in [1.4, 4.6]) {
    for (final p in _probes(clip, radius, -d)) {
      expect(band.contains(p), isFalse, reason: '$why: $d px in at $p');
    }
  }
}

Widget _scoped(BuildContext context, Widget? child) =>
    AppThemeScopes(child: child!);

Future<void> _pump(
  WidgetTester tester,
  TargetPlatform platform,
  Widget body,
) async {
  FocusManager.instance.highlightStrategy =
      FocusHighlightStrategy.alwaysTraditional;
  addTearDown(
    () => FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.automatic,
  );
  resetFocusRingInput();
  await tester.pumpWidget(
    MaterialApp(
      theme: buildHermesLightTheme().copyWith(platform: platform),
      builder: _scoped,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: Padding(padding: const EdgeInsets.all(24), child: body),
        ),
      ),
    ),
  );
}

/// Focuses the first control in [inside]'s subtree, or the nearest one above.
Future<void> _focus(WidgetTester tester, Finder inside) async {
  final target = tester.element(inside.first);
  FocusNode? node;
  for (final n in FocusManager.instance.rootScope.traversalDescendants) {
    var within = false;
    n.context?.visitAncestorElements((e) {
      within = identical(e, target);
      return !within;
    });
    if (within) {
      node = n;
      break;
    }
  }
  (node ?? Focus.of(target)).requestFocus();
  await tester.pumpAndSettle();
}

Finder _materialOf(Finder inside) =>
    find.ancestor(of: inside, matching: find.byType(Material)).first;

void main() {
  setUp(resetFocusRingInput);

  Future<void> outside(
    WidgetTester tester, {
    required TargetPlatform platform,
    required Widget body,
    required Finder focus,
    required Finder shape,
    double? radius,
  }) async {
    await _pump(tester, platform, body);
    await _focus(tester, focus);
    final painted = _painted(tester, shape);
    expectRingHugs(_ringBand(tester), (
      painted.$1,
      radius ?? painted.$2,
    ), reason: 'the ring hugs the painted shape');
  }

  group('outside rings follow the painted shape', () {
    testWidgets('new chat button', (tester) async {
      await outside(
        tester,
        platform: TargetPlatform.android,
        body: NewChatFab(onPressed: () {}),
        focus: find.byType(FloatingActionButton),
        shape: find
            .descendant(
              of: find.byType(FloatingActionButton),
              matching: find.byType(Material),
            )
            .first,
      );
    });

    testWidgets('scroll to latest: a circle round the 40 dp circle, not its '
        '48 dp tap box', (tester) async {
      await outside(
        tester,
        platform: TargetPlatform.android,
        body: ChangeNotifierProvider(
          create: (_) => ComposerHeightNotifier(),
          child: SizedBox(
            width: 300,
            height: 300,
            child: Stack(
              children: [
                ScrollToLatestButton(
                  animation: const AlwaysStoppedAnimation(1),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
        focus: find.byType(FloatingActionButton),
        shape: find
            .descendant(
              of: find.byType(FloatingActionButton),
              matching: find.byType(Material),
            )
            .first,
      );
      final circle = tester.getRect(
        find
            .descendant(
              of: find.byType(FloatingActionButton),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(circle.size, const Size(40, 40));
    });

    testWidgets('new task button', (tester) async {
      await outside(
        tester,
        platform: TargetPlatform.android,
        body: NewTaskFab(onPressed: () {}),
        focus: find.byType(FloatingActionButton),
        shape: find
            .descendant(
              of: find.byType(FloatingActionButton),
              matching: find.byType(Material),
            )
            .first,
      );
    });

    for (final platform in [
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.macOS,
    ]) {
      testWidgets('weekday toggle (${platform.name})', (tester) async {
        await outside(
          tester,
          platform: platform,
          body: SchedulePicker(
            spec: const WeeklySpec({1, 2, 3}, 9, 0),
            now: DateTime(2026, 11, 22),
            onChanged: (_) {},
          ),
          focus: find.text('Tue'),
          shape: _materialOf(find.text('Tue')),
        );
      });
    }

    testWidgets('Bot Screen key', (tester) async {
      await outside(
        tester,
        platform: TargetPlatform.android,
        body: BotScreenKeyBar(
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
        focus: find.text('Esc'),
        shape: _materialOf(find.text('Esc')),
      );
    });

    testWidgets('tool value copy button', (tester) async {
      await outside(
        tester,
        platform: TargetPlatform.android,
        body: ToolValueCopyButton(label: 'Copy result', onPressed: () {}),
        focus: find.byType(InkWell),
        shape: find.byType(InkWell),
      );
    });

    testWidgets('code block copy button', (tester) async {
      await outside(
        tester,
        platform: TargetPlatform.android,
        body: HermesCodeBlock(
          name: 'dart',
          codes: 'void main() {}\n',
          style: const CodeBlockStyle(),
        ),
        focus: find.byType(mui.InkWell),
        shape: find
            .ancestor(
              of: find.byType(mui.InkWell),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
    });

    testWidgets('voice orb', (tester) async {
      await outside(
        tester,
        platform: TargetPlatform.android,
        body: VoiceOrb(state: VoiceOrbState.speaking, onTap: () {}),
        focus: find.byType(InkResponse),
        shape: find
            .descendant(
              of: find.byType(InkResponse),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
    });

    testWidgets('link', (tester) async {
      await outside(
        tester,
        platform: TargetPlatform.android,
        body: WhatsTheDifferenceLink(onTap: () {}),
        focus: find.byType(InkWell),
        shape: find.byType(InkWell),
        radius: 0,
      );
    });

    testWidgets('iOS sliding control', (tester) async {
      await outside(
        tester,
        platform: TargetPlatform.iOS,
        body: AdaptiveSegmentedControl<int>(
          value: 0,
          segments: const {0: 'Chats', 1: 'Files'},
          onChanged: (_) {},
        ),
        focus: find.byType(CupertinoSlidingSegmentedControl<int>),
        shape: find
            .descendant(
              of: find.byType(CupertinoSlidingSegmentedControl<int>),
              matching: find.byType(DecoratedBox),
            )
            .first,
        radius: 9,
      );
    });
  });

  group('rings merged earlier follow the painted shape too', () {
    for (final (name, build) in <(String, Widget Function())>[
      (
        'FilledButton',
        () => FilledButton(onPressed: () {}, child: const Text('Filled')),
      ),
      (
        'OutlinedButton',
        () => OutlinedButton(onPressed: () {}, child: const Text('Outlined')),
      ),
      (
        'TextButton',
        () => TextButton(onPressed: () {}, child: const Text('Text')),
      ),
      (
        'IconButton',
        () => IconButton(
          onPressed: () {},
          tooltip: 'Add',
          icon: const Icon(Icons.add),
        ),
      ),
      (
        'FilterChip',
        () => FilterChip(
          label: const Text('Chip'),
          selected: false,
          onSelected: (_) {},
        ),
      ),
      (
        'ChoiceChip',
        () => ChoiceChip(
          label: const Text('Chip'),
          selected: false,
          onSelected: (_) {},
        ),
      ),
    ]) {
      testWidgets('$name (focusRingShape / chip theme)', (tester) async {
        await _pump(tester, TargetPlatform.android, build());
        final target = switch (name) {
          'FilledButton' => find.byType(FilledButton),
          'OutlinedButton' => find.byType(OutlinedButton),
          'TextButton' => find.byType(TextButton),
          'IconButton' => find.byType(IconButton),
          _ => find.byType(RawChip),
        };
        await _focus(tester, target);
        final material = find
            .descendant(of: target, matching: find.byType(Material))
            .first;
        final shape = tester.widget<Material>(material).shape;
        final base = (shape! as FocusRingBorder).base;
        final rect = tester.getRect(material);
        final radius = switch (base) {
          RoundedRectangleBorder(:final borderRadius) =>
            (borderRadius as BorderRadius).topLeft.x,
          _ => rect.shortestSide / 2,
        };
        expectRingHugs(_borderBand(tester, material), (
          rect,
          radius,
        ), reason: name);
      });
    }

    for (final (name, build, tile) in <(String, Widget Function(), Finder)>[
      (
        'attach menu ListTile',
        () => const AttachMenu(origins: AttachOrigin.values, onPick: _ignore),
        find.byType(ListTile).last,
      ),
    ]) {
      testWidgets('$name: the ring is 2 px inside the tile', (tester) async {
        await _pump(tester, TargetPlatform.android, Card(child: build()));
        await _focus(tester, tile);
        final rect = tester.getRect(tile);
        expect(tester.getRect(_ringFinder), rect, reason: 'wraps the tile');
        expectRingInside(_ringBand(tester), rect, why: name);
        final card = tester.getRect(find.byType(Card));
        expect(card.contains(rect.topLeft), isTrue);
        expect(card.contains(rect.bottomRight), isTrue);
      });
    }

    testWidgets('FocusRingMenuItem and FocusRingCheckedMenuItem: 2 px inside '
        'the item, inside the menu', (tester) async {
      await _pump(
        tester,
        TargetPlatform.android,
        AdaptivePopupMenuButton<int>(
          tooltip: 'Menu',
          onSelected: (_) {},
          itemBuilder: (_) => const [
            PopupMenuItem<int>(value: 1, child: Text('One')),
            CheckedPopupMenuItem<int>(
              value: 2,
              checked: true,
              child: Text('Two'),
            ),
          ],
        ),
      );
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();
      // The press that opened the menu hides the ring until a key is used.
      await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
      final menu = tester.getRect(find.byType(Material).last);
      for (final (type, text) in [
        (find.byType(FocusRingMenuItem<int>), 'One'),
        (find.byType(FocusRingCheckedMenuItem<int>), 'Two'),
      ]) {
        await _focus(tester, type);
        final item = tester.getRect(type);
        expect(tester.getRect(_ringFinder), item, reason: '$text wraps item');
        expectRingInside(_ringBand(tester), item, why: text);
        expect(menu.inflate(0.1).contains(item.topLeft), isTrue);
        expect(menu.inflate(0.1).contains(item.bottomRight), isTrue);
        expect(_ringBand(tester).getBounds().inflate(0.1), isNot(isNull));
      }
    });
  });
}

void _ignore(AttachOrigin _) {}
