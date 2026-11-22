import 'dart:math' as math;
import 'dart:typed_data';

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
import 'package:hermes_app/src/chat/thread_search.dart';
import 'package:hermes_app/src/chat/widgets/mac_search_results.dart';
import 'package:hermes_app/src/files/widgets/file_previews.dart';
import 'package:hermes_app/src/platform_hint/platform_hint_repository.dart';
import 'package:hermes_app/src/platform_hint/widgets/platform_hint_prompt.dart';
import 'package:hermes_app/src/bot_screen/widgets/takeover_confirmation.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:hermes_app/src/profiles/widgets/recipient_picker.dart';
import 'package:hermes_app/src/schedules/widgets/schedules_mac_toolbar.dart';
import 'package:hermes_app/src/widgets/adaptive_tab_bar.dart';
import 'package:hermes_app/src/widgets/composer_selector_chip.dart';
import 'package:hermes_app/src/widgets/disclosure_tile.dart';
import 'package:hermes_app/src/widgets/grouped_form.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';

/// The drawn geometry of the keyboard focus ring against what is painted: the
/// ring follows the visible shape, not the layout box round it. An outside
/// ring's inner edge is 2 px outside the shape on every side, its corner radius
/// is the shape's plus 2; an inside ring's outer edge is 2 px inside it.

final _ringFinder = find.byWidgetPredicate(
  (w) => w is CustomPaint && w.foregroundPainter is FocusRingPainter,
);

/// A canvas that keeps the one rounded rectangle drawn on it, with the
/// transform in force when it was drawn (save, restore, translate and
/// transform are followed; a painter that drops or reverses its transform
/// draws somewhere else).
class _Recorder implements Canvas {
  final _stack = <Matrix4>[Matrix4.identity()];
  RRect? rrect;

  @override
  void save() => _stack.add(_stack.last.clone());

  @override
  void restore() => _stack.removeLast();

  @override
  void translate(double dx, double dy) =>
      _stack.last.multiply(Matrix4.translationValues(dx, dy, 0));

  @override
  void transform(Float64List matrix4) =>
      _stack.last.multiply(Matrix4.fromFloat64List(matrix4));

  @override
  void drawRRect(RRect rrect, Paint paint) {
    final m = _stack.last;
    // Only translations are expected: a scale would change the ring's width.
    expect(m.getMaxScaleOnAxis(), closeTo(1, 1e-6));
    this.rrect = RRect.fromRectAndRadius(
      MatrixUtils.transformRect(m, rrect.outerRect),
      Radius.circular(rrect.tlRadiusX),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// The band of the ring drawn by [FocusRing] or [HostFocusRing], in global
/// coordinates, and the painter that drew it.
(Path, FocusRingPainter) _ring(WidgetTester tester, [Finder? ring]) {
  final finder = ring ?? _ringFinder;
  expect(finder, findsOneWidget);
  final painter =
      tester.widget<CustomPaint>(finder).foregroundPainter! as FocusRingPainter;
  final box = tester.renderObject<RenderBox>(finder);
  final recorder = _Recorder();
  painter.paint(recorder, box.size);
  expect(recorder._stack, hasLength(1), reason: 'every save is restored');
  // The recorded rectangle is in the painting box's own coordinates (the
  // painter's transform included); the box's origin puts it on screen.
  final center = recorder.rrect!.shift(box.localToGlobal(Offset.zero));
  final half = painter.width / 2;
  RRect grow(double by) => RRect.fromRectAndRadius(
    center.outerRect.inflate(by),
    Radius.circular(center.tlRadiusX + by),
  );
  return (
    Path.combine(
      PathOperation.difference,
      Path()..addRRect(grow(half)),
      Path()..addRRect(grow(-half)),
    ),
    painter,
  );
}

Path _ringBand(WidgetTester tester, [Finder? ring]) => _ring(tester, ring).$1;

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
List<Offset> _probes(Rect shape, double? radius, double d) {
  final c = shape.center;
  final out = [
    Offset(c.dx, shape.top - d),
    Offset(c.dx, shape.bottom + d),
    Offset(shape.left - d, c.dy),
    Offset(shape.right + d, c.dy),
  ];
  if (radius != null) {
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
void expectRingInside(Path band, Rect clip, {double? radius, String? why}) {
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

/// The ring drawn now lies 2 px inside [clip] (a row, an item, a segment).
void expectInsideClip(WidgetTester tester, Rect clip, {String? why}) {
  final (band, painter) = _ring(tester);
  // The ring's outer radius is the clip's minus the inset.
  expectRingInside(
    band,
    clip,
    radius: math.min(painter.radius + painter.inset, clip.shortestSide / 2),
    why: why,
  );
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
  tester.view
    ..physicalSize = const Size(800, 1400)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildHermesLightTheme(platform: platform),
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

/// The platforms whose widgets use the sliding control.
const _appleOnly = [TargetPlatform.iOS, TargetPlatform.macOS];

/// The painted track of the sliding control of type [T].
Finder _track<T extends Object>() => find
    .descendant(
      of: find.byType(CupertinoSlidingSegmentedControl<T>),
      matching: find.byType(DecoratedBox),
    )
    .first;

/// A padded platform (the tap target of a button, chip and mini FAB is padded
/// to 48) and two desktop ones (shrink-wrapped): the layout box round a control
/// differs, the painted shape does not.
const _platforms = [
  TargetPlatform.android,
  TargetPlatform.macOS,
  TargetPlatform.linux,
];

/// [body] on each of [platforms], named after it.
void testOnPlatforms(
  String name,
  Future<void> Function(WidgetTester tester, TargetPlatform platform) body, {
  List<TargetPlatform> platforms = _platforms,
}) {
  for (final platform in platforms) {
    testWidgets('${platform.name}: $name', (tester) => body(tester, platform));
  }
}

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
    testOnPlatforms('new chat button', (tester, platform) async {
      await outside(
        tester,
        platform: platform,
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

    testOnPlatforms(
      'scroll to latest: a circle round the 40 dp circle, not its '
      '48 dp tap box',
      (tester, platform) async {
        await outside(
          tester,
          platform: platform,
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
      },
    );

    testOnPlatforms('new task button', (tester, platform) async {
      await outside(
        tester,
        platform: platform,
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
      TargetPlatform.linux,
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

    testOnPlatforms('Bot Screen key', (tester, platform) async {
      await outside(
        tester,
        platform: platform,
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

    testOnPlatforms('tool value copy button', (tester, platform) async {
      await outside(
        tester,
        platform: platform,
        body: ToolValueCopyButton(label: 'Copy result', onPressed: () {}),
        focus: find.byType(InkWell),
        shape: find.byType(InkWell),
      );
    });

    testOnPlatforms('code block copy button', (tester, platform) async {
      await outside(
        tester,
        platform: platform,
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

    testOnPlatforms('voice orb', (tester, platform) async {
      await outside(
        tester,
        platform: platform,
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

    testOnPlatforms('link', (tester, platform) async {
      await outside(
        tester,
        platform: platform,
        body: WhatsTheDifferenceLink(onTap: () {}),
        focus: find.byType(InkWell),
        shape: find.byType(InkWell),
      );
    });

    // The other sliding-control sites, each inside its own widget.
    testOnPlatforms('GroupedSegmentedRow sliding control', (
      tester,
      platform,
    ) async {
      await outside(
        tester,
        platform: platform,
        body: GroupedSection(
          children: [
            GroupedSegmentedRow<int>(
              value: 0,
              segments: const {0: 'One', 1: 'Two'},
              onChanged: (_) {},
            ),
          ],
        ),
        focus: find.byType(CupertinoSlidingSegmentedControl<int>),
        shape: _track<int>(),
      );
    }, platforms: _appleOnly);

    testOnPlatforms('MarkdownModeControl sliding control', (
      tester,
      platform,
    ) async {
      await outside(
        tester,
        platform: platform,
        body: MarkdownModeControl(showSource: false, onChanged: (_) {}),
        focus: find.byType(CupertinoSlidingSegmentedControl<bool>),
        shape: _track<bool>(),
      );
    }, platforms: _appleOnly);

    testOnPlatforms('ScheduleScopeControl sliding control', (
      tester,
      platform,
    ) async {
      await outside(
        tester,
        platform: platform,
        body: ScheduleScopeControl(allProfiles: false, onChanged: (_) {}),
        focus: find.byType(CupertinoSlidingSegmentedControl<bool>),
        shape: _track<bool>(),
      );
    }, platforms: _appleOnly);

    testOnPlatforms('MacToolbarTabs sliding control', (tester, platform) async {
      await outside(
        tester,
        platform: platform,
        body: DefaultTabController(
          length: 2,
          child: const MacToolbarTabs(labels: ['Chats', 'Files']),
        ),
        focus: find.byType(CupertinoSlidingSegmentedControl<int>),
        shape: _track<int>(),
      );
    }, platforms: _appleOnly);

    testOnPlatforms('MacSearchResults scope control', (tester, platform) async {
      await outside(
        tester,
        platform: platform,
        body: SizedBox(
          width: 300,
          height: 300,
          child: MacSearchResults(
            query: 'plan',
            status: ThreadSearchStatus.done,
            hits: const [],
            scope: ThreadSearchScope.profile,
            recent: const [],
            onOpen: (_) {},
            onPickRecent: (_) {},
            onScopeChanged: (_) {},
          ),
        ),
        focus: find.byType(CupertinoSlidingSegmentedControl<ThreadSearchScope>),
        shape: _track<ThreadSearchScope>(),
      );
    }, platforms: _appleOnly);

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
      testOnPlatforms('$name (focusRingShape / chip theme)', (
        tester,
        platform,
      ) async {
        await _pump(tester, platform, build());
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
      testOnPlatforms('$name: the ring is 2 px inside the tile', (
        tester,
        platform,
      ) async {
        await _pump(tester, platform, Card(child: build()));
        await _focus(tester, tile);
        final rect = tester.getRect(tile);
        expect(tester.getRect(_ringFinder), rect, reason: 'wraps the tile');
        expectInsideClip(tester, rect, why: name);
        final card = tester.getRect(find.byType(Card));
        expect(card.contains(rect.topLeft), isTrue);
        expect(card.contains(rect.bottomRight), isTrue);
      });
    }

    testOnPlatforms(
      'FocusRingMenuItem and FocusRingCheckedMenuItem: 2 px inside '
      'the item, inside the menu',
      (tester, platform) async {
        await _pump(
          tester,
          platform,
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
          expectInsideClip(tester, item, why: text);
          // The whole ring, not only its item, lies inside the menu.
          final bounds = _ringBand(tester).getBounds();
          expect(menu.contains(bounds.topLeft), isTrue);
          expect(menu.contains(bounds.bottomRight), isTrue);
          expect(bounds, item.deflate(2).inflate(0.5).intersect(bounds));
        }
      },
      platforms: [TargetPlatform.android, TargetPlatform.linux],
    );
  });

  group('inside rings lie 2 px within their clip or item', () {
    testOnPlatforms('GroupedRow', (tester, platform) async {
      await _pump(
        tester,
        platform,
        SizedBox(
          width: 320,
          child: GroupedSection(
            children: [
              GroupedRow(title: 'Setting', onTap: () {}),
              GroupedRow(title: 'Other', onTap: () {}),
            ],
          ),
        ),
      );
      await _focus(tester, find.byType(GroupedRow).first);
      final row = tester.getRect(find.byType(GroupedRow).first);
      expect(tester.getRect(_ringFinder), row, reason: 'wraps the row');
      expectInsideClip(tester, row, why: 'GroupedRow');
    });

    testOnPlatforms('PillSegmentedControl segment', (tester, platform) async {
      await _pump(
        tester,
        platform,
        PillSegmentedControl<int>(
          value: 0,
          segments: const {0: 'Chats', 1: 'Files'},
          onChanged: (_) {},
        ),
      );
      final segment = find.byType(InkWell).at(1);
      await _focus(tester, segment);
      final rect = tester.getRect(segment);
      expect(tester.getRect(_ringFinder), rect, reason: 'wraps the segment');
      expectInsideClip(tester, rect, why: 'segment');
      expect(
        tester
            .getRect(find.byType(PillSegmentedControl<int>))
            .contains(rect.center),
        isTrue,
      );
    });

    testOnPlatforms('ComposerSelectorChip (the model pill)', (
      tester,
      platform,
    ) async {
      await _pump(
        tester,
        platform,
        ComposerSelectorChip(label: 'claude-sonnet · high', onPressed: () {}),
      );
      await _focus(tester, find.byType(InkWell));
      final ink = tester.getRect(find.byType(InkWell));
      expect(tester.getRect(_ringFinder), ink, reason: 'wraps the main part');
      expectInsideClip(tester, ink, why: 'pill');
      // The pill is the clip: its Material is the area the ring stays in.
      final pill = tester.getRect(
        find
            .ancestor(of: find.byType(InkWell), matching: find.byType(Material))
            .first,
      );
      final bounds = _ringBand(tester).getBounds();
      expect(pill.contains(bounds.topLeft), isTrue);
      expect(pill.contains(bounds.bottomRight), isTrue);
    });

    testOnPlatforms('Android SegmentedButton segment (host ring)', (
      tester,
      platform,
    ) async {
      await _pump(
        tester,
        platform,
        AdaptiveSegmentedControl<int>(
          value: 0,
          segments: const {0: 'Chats', 1: 'Files', 2: 'Tasks'},
          onChanged: (_) {},
        ),
      );
      await _focus(tester, find.text('Files'));
      final segment = tester.getRect(find.byType(TextButton).at(1));
      // The control crops its segments to 28 dp.
      final shown = Rect.fromLTWH(segment.left, segment.top, segment.width, 28);
      expectInsideClip(tester, shown, why: 'segment');
    }, platforms: [TargetPlatform.android]);

    testOnPlatforms('DisclosureTile header (host ring)', (
      tester,
      platform,
    ) async {
      await _pump(
        tester,
        platform,
        const SizedBox(
          width: 320,
          child: DisclosureTile(
            initiallyExpanded: true,
            title: Text('Tool output'),
            children: [Text('3 files')],
          ),
        ),
      );
      await _focus(tester, find.text('Tool output'));
      expectInsideClip(
        tester,
        tester.getRect(find.byType(ListTile)),
        why: 'header',
      );
    });

    testOnPlatforms('Mac menu row', (tester, platform) async {
      // A row outside a menu has no focus of its own: give it one.
      final node = FocusNode();
      addTearDown(node.dispose);
      await _pump(
        tester,
        platform,
        SizedBox(
          width: 200,
          child: Focus(
            focusNode: node,
            child: const MacMenuRow(child: Text('Rename')),
          ),
        ),
      );
      node.requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expectInsideClip(
        tester,
        tester.getRect(find.byType(MacMenuRow)),
        why: 'row',
      );
    }, platforms: [TargetPlatform.macOS]);

    final tiles = <String, (Widget, Finder)>{
      'recipient picker ListTile': (
        RecipientPicker(
          profiles: const [
            HermesProfile(name: 'writer', displayName: 'Writer'),
            HermesProfile(name: 'research', displayName: 'Research'),
          ],
          selectedProfile: 'writer',
          onSelected: (_) {},
        ),
        find.byType(ListTile).first,
      ),
      'platform hint CheckboxListTile': (
        Card(
          child: PlatformHintPrompt(
            profiles: const ['default', 'work'],
            text: appPlatformHint,
            selected: const {'default'},
            onToggle: (_, _) {},
            onAdd: () {},
            onLater: () {},
            onNever: () {},
          ),
        ),
        find.byType(CheckboxListTile).last,
      ),
      'take-over SwitchListTile': (
        Card(
          child: TakeoverConfirmation(onCancel: () {}, onConfirm: (_) {}),
        ),
        find.byType(SwitchListTile),
      ),
    };
    for (final MapEntry(key: name, value: (widget, tile)) in tiles.entries) {
      testOnPlatforms(name, (tester, platform) async {
        await _pump(tester, platform, SizedBox(width: 360, child: widget));
        await _focus(tester, tile);
        final rect = tester.getRect(tile);
        expect(tester.getRect(_ringFinder), rect, reason: 'wraps the tile');
        expectInsideClip(tester, rect, why: name);
      });
    }
  });
}

void _ignore(AttachOrigin _) {}
