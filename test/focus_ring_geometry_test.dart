import 'dart:convert' show base64Decode;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cupertino_ui/cupertino_ui.dart'
    show CupertinoSlidingSegmentedControl;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
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
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/bot_screen/bot_screen_preview_model.dart';
import 'package:hermes_app/src/bot_screen/widgets/bot_screen_preview.dart';
import 'package:hermes_app/src/chat/starter_prompts.dart';
import 'package:hermes_app/src/chat/widgets/attachment_views.dart';
import 'package:hermes_app/src/chat/widgets/reasoning_block.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_group.dart';
import 'package:hermes_app/src/chat/widgets/welcome_view.dart';
import 'package:hermes_app/src/models/model_provider_option.dart'
    show ModelChoice;
import 'package:hermes_app/src/models/widgets/model_picker.dart';
import 'package:hermes_app/src/widgets/grouped_form.dart';
import 'package:hermes_app/src/chat/media/media_store.dart';
import 'package:hermes_app/src/macos/mac_source_list.dart';
import 'package:hermes_app/src/macos/mac_toolbar_search_field.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/widgets/settings_search_field.dart';
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
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../widgetbook/bot_screen_fixture.dart';
import '../widgetbook/fixtures.dart' show modelOptions, searchHits;
import 'support/fake_hermes_server.dart';
import 'support/popup_trigger_callers.dart';
import 'support/test_localizations.dart';
import 'support/wait_until.dart';

import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/thread_housekeeping.dart';
import 'package:hermes_app/src/chat/thread_search.dart';
import 'package:hermes_app/src/chat/widgets/mac_search_results.dart';
import 'package:hermes_app/src/chat/widgets/mac_thread_row.dart';
import 'package:hermes_app/src/chat/widgets/sidebar_row.dart';
import 'package:hermes_app/src/chat/widgets/thread_actions_menu.dart';
import 'package:hermes_app/src/chat/widgets/thread_search_view.dart';
import 'package:hermes_app/src/chat/widgets/thread_sidebar.dart';
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
import 'package:hermes_app/src/widgets/grouped_list.dart';
import 'package:hermes_app/src/widgets/named_icon_button.dart';
import 'package:hermes_app/src/widgets/named_popup_menu_button.dart';
import 'package:hermes_app/src/chat/activity/widgets/activity_line.dart';
import 'package:hermes_app/src/chat/activity/widgets/activity_line_model.dart';
import 'package:hermes_app/src/chat/activity/working_summary.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/checkpoints/checkpoints_state.dart';
import 'package:hermes_app/src/chat/checkpoints/widgets/file_checkpoints_row.dart';
import 'package:hermes_app/src/chat/context/context_models.dart';
import 'package:hermes_app/src/chat/context/context_state.dart';
import 'package:hermes_app/src/chat/context/widgets/context_format.dart';
import 'package:hermes_app/src/chat/context/widgets/context_row.dart';
import 'package:hermes_app/src/chat/subagents/agent_models.dart';
import 'package:hermes_app/src/chat/subagents/widgets/agent_row.dart';
import 'package:hermes_app/src/chat/widgets/subagent_card.dart';
import 'package:hermes_app/src/chat/widgets/tool_json_tree.dart';
import 'package:hermes_app/src/files/widgets/file_row.dart';
import 'package:hermes_app/src/kanban/kanban_models.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_card.dart';
import 'package:hermes_app/src/schedules/widgets/schedule_advanced_row.dart';
import 'package:hermes_app/src/server_care/widgets/server_restart_banner.dart';
import 'package:hermes_app/src/widgets/grouped_action_row.dart';
import 'package:hermes_app/src/workspaces/widgets/working_directory_line.dart';
import 'package:hermes_app/src/workspaces/widgets/working_directory_row.dart';

/// The drawn geometry of the keyboard focus ring against what is painted: the
/// ring follows the visible shape, not the layout box round it. An outside
/// ring's inner edge is 2 px outside the shape on every side, its corner radius
/// is the shape's plus 2; an inside ring's outer edge is 2 px inside it.

final _ringFinder = find.byWidgetPredicate(
  (w) => w is CustomPaint && w.foregroundPainter is FocusRingPainter,
);

/// Whether [inner] lies inside [outer].
bool _within(Rect outer, Rect inner) =>
    inner.left >= outer.left &&
    inner.top >= outer.top &&
    inner.right <= outer.right &&
    inner.bottom <= outer.bottom;

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
    Radius.circular(math.max(0, center.tlRadiusX + by)),
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
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildHermesLightTheme(platform: platform),
      builder: (_, child) => AppThemeScopes(child: child!),
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

  group('outside tap targets of F.427 (table D)', () {
    const platforms = [
      TargetPlatform.android,
      TargetPlatform.macOS,
      TargetPlatform.linux,
      TargetPlatform.windows,
    ];

    /// The ring wraps [ink] exactly (so it sits 2 px outside the control, the
    /// paint reaches past its bounds and nothing changes in layout), is 2 px
    /// wide in the link colour, and its band lies 2 to 4 px outside the
    /// control's painted shape, whose corner radius is [radius].
    Future<void> expectOutsideTarget(
      WidgetTester tester, {
      required TargetPlatform platform,
      required Widget body,
      required Finder ink,
      required double radius,
      required String name,
    }) async {
      await _pump(tester, platform, body);
      await _focus(tester, ink);
      final rect = tester.getRect(ink.first);
      expect(tester.getRect(_ringFinder), rect, reason: '$name: wraps it');
      final (band, painter) = _ring(tester);
      expect(painter.width, kFocusRingWidth);
      expect(painter.inset, -(kFocusRingOffset + kFocusRingWidth));
      expect(painter.color, tester.element(_ringFinder).hermesColors.link);
      expectRingHugs(band, (rect, radius), reason: name);
    }

    /// Only the keyboard shows the ring: a pointer press hides it and the
    /// next key brings it back.
    Future<void> expectKeyboardOnly(WidgetTester tester) async {
      expect(_ringFinder, findsOneWidget, reason: 'keyboard focus');
      await tester.tapAt(
        const Offset(790, 1390),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expect(_ringFinder, findsNothing, reason: 'a pointer press hides it');
      await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(_ringFinder, findsOneWidget, reason: 'the next key shows it');
    }

    testOnPlatforms('tool-call group header: radius 8', (
      tester,
      platform,
    ) async {
      await expectOutsideTarget(
        tester,
        platform: platform,
        body: const ToolCallGroup(
          calls: [
            ToolCall(name: 'terminal', summary: 'ls'),
            ToolCall(name: 'read_file', summary: 'Makefile'),
          ],
        ),
        ink: find.byType(InkWell),
        radius: 8,
        name: 'tool-call group header',
      );
    }, platforms: platforms);

    testOnPlatforms('reasoning toggle: radius 8', (tester, platform) async {
      await expectOutsideTarget(
        tester,
        platform: platform,
        body: const ReasoningBlock(text: 'Considered the options.'),
        ink: find.byType(InkWell),
        radius: 8,
        name: 'reasoning toggle',
      );
    }, platforms: platforms);

    testOnPlatforms('attachment card: radius 14', (tester, platform) async {
      await expectOutsideTarget(
        tester,
        platform: platform,
        body: const AttachmentCardFrame(
          attachment: ChatAttachment(
            name: 'report.pdf',
            kind: AttachmentKind.file,
            size: 4821,
          ),
          onTap: _ignoreTap,
        ),
        ink: find.byType(InkWell),
        radius: 14,
        name: 'attachment card',
      );
    }, platforms: platforms);

    testWidgets('macOS: the failed-download retry card takes the ring too', (
      tester,
    ) async {
      await expectOutsideTarget(
        tester,
        platform: TargetPlatform.macOS,
        body: const AttachmentCardFrame(
          attachment: ChatAttachment(
            name: 'report.pdf',
            kind: AttachmentKind.file,
          ),
          notice: "Couldn't download.",
          noticeIsError: true,
          onTap: _ignoreTap,
        ),
        ink: find.byType(InkWell),
        radius: 14,
        name: 'retry card',
      );
    });

    /// The card with its Save button, as a chat shows a downloaded file. Save
    /// draws its own ring; the card's must stay off while Save has the focus.
    Widget cardWithSave({VoidCallback? onTap}) => AttachmentCardFrame(
      attachment: const ChatAttachment(
        name: 'report.pdf',
        kind: AttachmentKind.file,
        size: 4821,
      ),
      onTap: onTap,
      trailing: NamedIconButton(
        label: 'Save report.pdf',
        icon: AppIcons.download,
        onPressed: _ignoreTap,
      ),
    );

    final cardRing = find.byWidgetPredicate(
      (w) =>
          w is CustomPaint &&
          w.foregroundPainter is FocusRingPainter &&
          w.foregroundPainter is! HostFocusRingPainter &&
          (w.foregroundPainter! as FocusRingPainter).radius == 14 + 4,
    );

    testOnPlatforms('attachment card: no card ring while Save has focus', (
      tester,
      platform,
    ) async {
      // A Mac card has no tap and is not focusable; the others are.
      final onTap = platform == TargetPlatform.macOS ? null : _ignoreTap;
      await _pump(tester, platform, cardWithSave(onTap: onTap));
      await _focus(tester, find.byType(NamedIconButton));
      expect(
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<NamedIconButton>(),
        isNotNull,
        reason: 'Save has the focus',
      );
      expect(cardRing, findsNothing, reason: 'the card ring stays off');
    }, platforms: platforms);

    testOnPlatforms(
      'attachment card: the card ring shows on its own focus',
      (tester, platform) async {
        await _pump(tester, platform, cardWithSave(onTap: _ignoreTap));
        // The card's own node: the nearest one above its content.
        Focus.of(
          tester.element(
            find.descendant(
              of: find.byType(InkWell),
              matching: find.byType(Row),
            ),
          ),
        ).requestFocus();
        await tester.pumpAndSettle();
        expect(cardRing, findsOneWidget, reason: 'the card itself has focus');
      },
      platforms: [
        for (final p in platforms)
          if (p != TargetPlatform.macOS) p,
      ],
    );

    testOnPlatforms('Bot Screen preview: radius 8, into the 4 px above', (
      tester,
      platform,
    ) async {
      await expectOutsideTarget(
        tester,
        platform: platform,
        body: SizedBox(
          width: 360,
          child: BotScreenPreview(
            model: BotScreenPreviewFrame(bytes: botScreenFixturePng()),
            onTap: () {},
          ),
        ),
        ink: find.byType(InkWell),
        radius: 8,
        name: 'Bot Screen preview',
      );
    }, platforms: platforms);

    Widget welcome() => SizedBox(
      height: 460,
      width: 360,
      child: WelcomeView(
        greetingName: 'Ada',
        prompts: buildStarterPrompts(const StarterContext()),
        onPick: (_) {},
      ),
    );

    testOnPlatforms('welcome card: radius 14', (tester, platform) async {
      await expectOutsideTarget(
        tester,
        platform: platform,
        body: welcome(),
        ink: find.byType(InkWell).first,
        radius: 14,
        name: 'welcome card',
      );
    }, platforms: platforms);

    testWidgets('welcome card: the ring follows the keyboard only', (
      tester,
    ) async {
      await _pump(tester, TargetPlatform.linux, welcome());
      await _focus(tester, find.byType(InkWell).first);
      await expectKeyboardOnly(tester);
    });

    Widget picker() => SizedBox(
      width: 420,
      height: 900,
      child: ModelPicker(
        options: modelOptions,
        selected: const ModelChoice(
          'anthropic',
          'claude-opus-4',
          effort: 'high',
        ),
        onChanged: (_) {},
      ),
    );
    final pillBox = find.byKey(const Key('effort-medium'));
    final pillInk = find.descendant(
      of: pillBox,
      matching: find.byType(InkWell),
    );

    /// The ring of the effort pill wraps the painted pill, not the hit area
    /// round it ([hit] tall), and follows the shape: [radius] of it.
    Future<void> expectEffortPill(
      WidgetTester tester, {
      required TargetPlatform platform,
      required double Function(Rect pill) radius,
      required double height,
      required double hit,
      double textScale = 1,
    }) async {
      await _pump(
        tester,
        platform,
        MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: picker(),
        ),
      );
      // From a large text scale on the pills sit at the end of the list.
      if (pillBox.evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          pillBox,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        // The drag was a pointer press; this test is about the keyboard.
        await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
      }
      await _focus(tester, pillInk);
      final rect = tester.getRect(pillInk);
      expect(rect.height, greaterThanOrEqualTo(height - 0.01));
      expect(
        tester.getRect(_ringFinder),
        rect,
        reason: 'wraps the painted pill, not its hit area',
      );
      if (hit > height) {
        expect(tester.getRect(pillBox).height, greaterThanOrEqualTo(hit));
      }
      final (band, painter) = _ring(tester);
      expect(painter.width, kFocusRingWidth);
      expect(painter.inset, -(kFocusRingOffset + kFocusRingWidth));
      expectRingHugs(band, (rect, radius(rect)), reason: 'effort pill');
    }

    testOnPlatforms(
      'effort pill: a stadium that follows the height',
      (tester, platform) async {
        await expectEffortPill(
          tester,
          platform: platform,
          radius: (pill) => pill.height / 2,
          height: 40,
          hit: platform == TargetPlatform.android ? 48 : 40,
        );
      },
      platforms: const [
        TargetPlatform.android,
        TargetPlatform.linux,
        TargetPlatform.windows,
      ],
    );

    testWidgets('effort pill (Material, text 3x): the radius follows the '
        'taller pill', (tester) async {
      await expectEffortPill(
        tester,
        platform: TargetPlatform.android,
        textScale: 3,
        radius: (pill) => pill.height / 2,
        height: 40,
        hit: 48,
      );
      expect(
        tester.getRect(pillInk).height,
        greaterThan(44),
        reason: 'grew with the text',
      );
    });

    testWidgets('effort pill (iPhone): radius 9', (tester) async {
      await expectEffortPill(
        tester,
        platform: TargetPlatform.iOS,
        radius: (_) => 9,
        height: 36,
        hit: 44,
      );
    });

    testWidgets('effort pill (Mac): radius 7', (tester) async {
      await expectEffortPill(
        tester,
        platform: TargetPlatform.macOS,
        radius: (_) => 7,
        height: 28,
        hit: 28,
      );
    });

    testWidgets('effort pill: the ring follows the keyboard only', (
      tester,
    ) async {
      await _pump(tester, TargetPlatform.android, picker());
      await _focus(tester, pillInk);
      await expectKeyboardOnly(tester);
    });

    testWidgets('Mac pop-up value: radius 6', (tester) async {
      await expectOutsideTarget(
        tester,
        platform: TargetPlatform.macOS,
        body: SizedBox(
          width: 360,
          child: GroupedSection(
            children: [
              GroupedValueRow(title: 'Model', value: 'opus', onTap: () {}),
            ],
          ),
        ),
        // The row's own ink well takes no focus (no tap); the pop-up's does.
        ink: find.byType(InkWell).last,
        radius: 6,
        name: 'Mac pop-up value',
      );
    });

    // The case above builds a GroupedValueRow with an onTap, which draws its
    // own ring; the screens build a GroupedMenuRow, whose pop-up is a
    // PopupMenuButton around the whole row. Reached by Tab, as a user does.
    // [value] in a row [width] wide with [title]: one ring, on the pop-up
    // face, whatever shape the row gives it.
    Future<void> expectMenuRowRing(
      WidgetTester tester, {
      required double width,
      required String title,
      required String value,
      bool truncated = false,
      bool titleWraps = false,
    }) async {
      await _pump(
        tester,
        TargetPlatform.macOS,
        SizedBox(
          width: width,
          child: GroupedSection(
            children: [
              GroupedMenuRow<String>(
                title: title,
                options: [value, 'sonnet'],
                labelOf: (option) => option,
                selected: value,
                onSelected: (_) {},
              ),
            ],
          ),
        ),
      );
      final paragraph = tester.renderObject<RenderParagraph>(find.text(value));
      expect(paragraph.didExceedMaxLines, truncated, reason: 'value truncates');
      final titleParagraph = tester.renderObject<RenderParagraph>(
        find.text(title),
      );
      expect(
        titleParagraph.size.height > 1.5 * 12 * 1.3,
        titleWraps,
        reason: 'title wraps',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      final face = find
          .ancestor(of: find.text(value), matching: find.byType(Material))
          .first;
      expect(_ringFinder, findsOneWidget, reason: 'the pop-up shows a ring');
      expect(tester.getRect(_ringFinder), tester.getRect(face));
      final (band, painter) = _ring(tester);
      expect(painter.width, kFocusRingWidth);
      expect(painter.inset, -(kFocusRingOffset + kFocusRingWidth));
      expectRingHugs(band, (
        tester.getRect(face),
        6,
      ), reason: 'Mac pop-up value of a GroupedMenuRow');
      await expectKeyboardOnly(tester);
    }

    testWidgets('Mac pop-up value of a GroupedMenuRow, reached by Tab: '
        'radius 6', (tester) async {
      await expectMenuRowRing(
        tester,
        width: 360,
        title: 'Model',
        value: 'opus',
      );
    });

    testWidgets('Mac pop-up value of a GroupedMenuRow whose value truncates, '
        'reached by Tab: the ring is round the shortened face', (tester) async {
      await expectMenuRowRing(
        tester,
        width: 300,
        title: 'Profile',
        value: 'Aktives Profil (default) mit weiteren Einstellungen',
        truncated: true,
      );
    });

    testWidgets('Mac pop-up value of a GroupedMenuRow whose title wraps in a '
        'narrow row, reached by Tab: the ring is round the face', (
      tester,
    ) async {
      await expectMenuRowRing(
        tester,
        width: 280,
        title: 'Bei Abschluss benachrichtigen',
        value: 'Aktives Profil (default) mit weiteren Einstellungen',
        truncated: true,
        titleWraps: true,
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

  group('rows and cards of F.427 (tables B and C)', _insideRowTests);
  group('sidebar rows of F.427 (table A)', _sidebarRowTests);
  group('iOS popup triggers of F.441', _popupTriggerTests);

  group('gesture-detector controls of F.441', () {
    // A 240 by 160 picture, so the thumbnail shows at its full size.
    final landscape = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAPAAAACgCAIAAAC9uXYyAAABU0lEQVR42u3SQREAEBQA0Z9JCCGchRBCEsHkcFXB92Zegp2NsTakERJgaDA0GBoMjaHB0GBoMDQYGkODocHQYGgwNIYGQ4OhwdBgaAwNhgZDg6HB0BgaDA2GBkODoTE0GBoMDYYGQ2NoMDQYGgyNocHQYGgwNBgaQ4OhwdBgaDA0hgZDg6HB0GBoDA2GBkODocHQGBoMDYYGQ4OhMTQYGgwNhgZDY2gwNBgaDA2GxtBgaDA0GBpDg6HB0GBoMDSGBkODocHQYGgMDc8OXWeDNAyNocHQYGgwNIYGQ4OhwdBgaAwNhgZDg6HB0BgaDA2GBkODoTE0GBoMDYYGQ2NoMDQYGgwNhsbQYGgwNBgaDI2hwdBgaDA0vw9deoU0DI2hwdBgaDA0hgZDg6HB0GBoDA2GBkODocHQGBoMDYYGQ4OhMTQYGgwNhgZDY2gwNBgaDA2XAy3QjoI76FvSAAAAAElFTkSuQmCC',
    );

    for (final (platform, width) in [
      (TargetPlatform.iOS, 32.0),
      (TargetPlatform.android, 36.0),
    ]) {
      testWidgets('${platform.name}: the settings search clear button is a '
          'round ring inside the field', (tester) async {
        await _pump(
          tester,
          platform,
          SizedBox(
            width: 360,
            child: SettingsSearchField(
              search: SettingsSearch(query: 'kan', onChanged: (_) {}),
            ),
          ),
        );
        const clear = Key('settings-search-clear');
        await _focus(tester, find.byKey(clear));
        final box = tester.getRect(find.byKey(clear));
        final field = tester.getRect(find.byType(SettingsSearchField));
        expect(box.width, width, reason: 'the icon and its 8 px each side');
        expect(box.height, field.height, reason: 'as tall as the field at 1x');
        expect(tester.getRect(_ringFinder), box, reason: 'wraps the tap box');
        final (_, painter) = _ring(tester);
        expect(painter.radius, width / 2 - 2, reason: 'half the box, less 2');
        expect(painter.inset, kFocusRingOffset, reason: 'inside');
        expectInsideClip(tester, box, why: 'clear button');
        expect(_within(field, box.deflate(2)), isTrue);
      });
    }

    for (final scale in [1.0, 3.1]) {
      testWidgets('android: the clear ring stays inside the stadium field at '
          'text scale $scale', (tester) async {
        await _pump(
          tester,
          TargetPlatform.android,
          MediaQuery.withClampedTextScaling(
            minScaleFactor: scale,
            maxScaleFactor: scale,
            child: SizedBox(
              width: 360,
              child: SettingsSearchField(
                search: SettingsSearch(query: 'kan', onChanged: (_) {}),
              ),
            ),
          ),
        );
        const clear = Key('settings-search-clear');
        await _focus(tester, find.byKey(clear));
        final field = tester.getRect(find.byType(SettingsSearchField));
        final band = _ringBand(tester);
        final stadium = Path()
          ..addRRect(
            RRect.fromRectAndRadius(field, Radius.circular(field.height / 2)),
          );
        final outside = Path.combine(PathOperation.difference, band, stadium);
        final cut = outside.computeMetrics().fold<double>(
          0,
          (sum, m) => sum + m.length,
        );
        expect(cut, lessThan(0.5), reason: 'no part of the ring is clipped');
        final box = tester.getRect(find.byKey(clear));
        expect(box.center.dy, closeTo(field.center.dy, 0.5));
      });
    }

    testWidgets('macOS: the End search button is a round-rect ring inside '
        'the 26 pt field', (tester) async {
      await _pump(
        tester,
        TargetPlatform.macOS,
        MacToolbarSearchField(
          query: 'backup',
          active: true,
          onChanged: (_) {},
          onEnd: () {},
        ),
      );
      const end = Key('toolbar-search-clear');
      await _focus(tester, find.byKey(end));
      final box = tester.getRect(find.byKey(end));
      final field = tester.getRect(find.byType(MacToolbarSearchField));
      expect(field.height, 26);
      expect(box.width, 26, reason: 'unchanged: 14 px icon, 6 px each side');
      expect(tester.getRect(_ringFinder), box, reason: 'wraps the tap box');
      final (band, painter) = _ring(tester);
      expect(painter.radius, 6);
      expect(painter.inset, kFocusRingOffset, reason: 'inside');
      expectInsideClip(tester, box, why: 'End search');
      // The ring's outer edge stays clear of the field's border.
      final outer = box.deflate(2);
      expect(_within(field.deflate(1), outer), isTrue);
      expect(band.getBounds().top, greaterThan(field.top + 1));
    });

    testWidgets('macOS: the sidebar section header is a full-bleed ring of '
        'radius 4 inside its edge', (tester) async {
      await _pump(
        tester,
        TargetPlatform.macOS,
        SizedBox(
          width: 260,
          child: MacSidebarSectionHeader(
            label: 'Today',
            collapsed: false,
            onToggle: () {},
          ),
        ),
      );
      await _focus(tester, find.byType(MacSidebarSectionHeader));
      final header = tester.getRect(find.byType(MacSidebarSectionHeader));
      expect(tester.getRect(_ringFinder), header, reason: 'wraps the header');
      expect(_ring(tester).$2.radius, 4);
      expectInsideClip(tester, header, why: 'section header');
    });

    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      testWidgets('${platform.name}: the image thumbnail has an outside ring '
          'at its own corner radius', (tester) async {
        await _pump(
          tester,
          platform,
          Provider<MediaStore?>.value(
            value: null,
            child: AttachmentThumbnail(
              attachment: ChatAttachment(
                name: 'photo.png',
                kind: AttachmentKind.image,
                bytes: landscape,
              ),
            ),
          ),
        );
        await waitUntil(
          tester,
          () => tester
              .widgetList<RawImage>(find.byType(RawImage))
              .any((image) => image.image != null),
          reason: 'the thumbnail to decode',
        );
        await _focus(tester, find.byType(AttachmentThumbnail));
        final picture = tester.getRect(find.byType(ImageThumbnailView));
        expect(picture.size, const Size(240, 160));
        expectRingHugs(_ringBand(tester), (
          picture,
          kHermesRadius,
        ), reason: 'the thumbnail');
        expect(tester.getRect(_ringFinder), picture, reason: 'wraps it');
      });
    }
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

/// An inside ring on a row or card: its outer edge lies [inset] px inside
/// [clip], the ring is 2 px wide, and the corner follows [radius], the ring's
/// own outer radius (0 for a square row, whose corners are probed as points).
void expectInsideRow(
  WidgetTester tester,
  Rect clip, {
  required double radius,
  double inset = 2,
  String? why,
}) {
  final (band, painter) = _ring(tester);
  expect(painter.radius, radius, reason: '$why: ring radius');
  expect(painter.inset, inset, reason: '$why: ring inset');
  expect(painter.width, 2, reason: '$why: ring width');
  final square = radius == 0;
  final clipRadius = square ? null : radius + inset;
  for (final d in [inset + 0.6, inset + 1.0, inset + 1.4]) {
    for (final p in _probes(clip, clipRadius, -d)) {
      expect(band.contains(p), isTrue, reason: '$why: $d px in at $p');
    }
  }
  for (final d in [inset - 0.6, inset + 2.6]) {
    for (final p in _probes(clip, clipRadius, -d)) {
      expect(band.contains(p), isFalse, reason: '$why: $d px in at $p');
    }
  }
  if (square) {
    // The ring's corner is square: on the diagonal it is in the band at
    // inset + 1, and not outside it.
    final c = inset + 1;
    expect(band.contains(clip.topLeft + Offset(c, c)), isTrue, reason: why);
    expect(band.contains(clip.bottomRight - Offset(c, c)), isTrue);
    expect(band.contains(clip.topLeft + const Offset(1, 1)), isFalse);
  }
}

/// The platforms an inside ring is checked on: the padded and the shrink-wrap
/// ones, Windows included.
const _rowPlatforms = [
  TargetPlatform.android,
  TargetPlatform.macOS,
  TargetPlatform.linux,
  TargetPlatform.windows,
];

/// A section's corner radius, less the ring's inset, per platform.
double _sectionRingRadius(TargetPlatform platform) => switch (platform) {
  TargetPlatform.iOS => 10,
  TargetPlatform.macOS => 8,
  _ => 12,
};

Widget _still(Widget child) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child,
  ),
);

/// Pumps [body] (360 wide, no animations), focuses [focus], and checks the
/// ring against [clipFinder] with the brief's radius and inset.
Future<void> _checkInside(
  WidgetTester tester, {
  required TargetPlatform platform,
  required Widget body,
  required Finder focus,
  required Finder clipFinder,
  required double radius,
  double inset = 2,
  String why = 'row',
}) async {
  await _pump(tester, platform, _still(SizedBox(width: 360, child: body)));
  await _focus(tester, focus);
  final clip = tester.getRect(clipFinder);
  expect(tester.getRect(_ringFinder), clip, reason: '$why: wraps the row');
  expectInsideRow(tester, clip, radius: radius, inset: inset, why: why);
}

void _insideRowTests() {
  const check = _checkInside;

  Finder inkIn(Type t) => find
      .descendant(of: find.byType(t).last, matching: find.byType(InkWell))
      .first;

  testOnPlatforms(
    'GroupedActionRow',
    (tester, platform) => check(
      tester,
      platform: platform,
      body: GroupedSection(
        children: [
          GroupedActionRow(
            title: 'Restart',
            icon: AppIcons.refresh,
            onPressed: () {},
          ),
          GroupedActionRow(
            title: 'Check',
            icon: AppIcons.play,
            onPressed: () {},
          ),
        ],
      ),
      focus: find.byType(GroupedActionRow).last,
      clipFinder: inkIn(GroupedActionRow),
      radius: _sectionRingRadius(platform),
      why: 'GroupedActionRow',
    ),
    platforms: [..._rowPlatforms, TargetPlatform.iOS],
  );

  testOnPlatforms(
    'iOS GroupedValueRow wrapper',
    (tester, platform) => check(
      tester,
      platform: platform,
      body: GroupedSection(
        children: [
          GroupedValueRow(title: 'Provider', value: 'Anthropic', onTap: () {}),
          GroupedValueRow(title: 'Model', value: 'sonnet', onTap: () {}),
        ],
      ),
      focus: find.byType(GroupedValueRow).last,
      clipFinder: inkIn(GroupedValueRow),
      radius: 10,
      why: 'GroupedValueRow',
    ),
    platforms: const [TargetPlatform.iOS],
  );

  testOnPlatforms(
    'Schedules Advanced row',
    (tester, platform) => check(
      tester,
      platform: platform,
      body: GroupedSection(
        children: [
          const GroupedRow(title: 'Prompt', value: 'Summarize'),
          ScheduleAdvancedRow(open: false, onTap: () {}),
        ],
      ),
      focus: find.byType(ScheduleAdvancedRow),
      clipFinder: inkIn(ScheduleAdvancedRow),
      radius: _sectionRingRadius(platform),
      why: 'Advanced row',
    ),
    platforms: [..._rowPlatforms, TargetPlatform.iOS],
  );

  testOnPlatforms(
    'FileRow',
    (tester, platform) => check(
      tester,
      platform: platform,
      body: FileRow(
        model: const FileRowModel(name: 'src', isFolder: true),
        onTap: () {},
      ),
      focus: find.byType(FileRow),
      clipFinder: find.byType(InkWell),
      radius: 0,
      why: 'FileRow',
    ),
    platforms: _rowPlatforms,
  );

  testOnPlatforms(
    'Activity line',
    (tester, platform) => check(
      tester,
      platform: platform,
      body: ActivityLine(
        model: ActivityLineModel.fromSummary(
          lookupAppLocalizations(const Locale('en')),
          WorkingSummary(
            sentence: const WorkingSentence(
              WorkingSentenceKind.goal,
              at: 1,
              text: 'Ship the report',
            ),
          ),
        ),
        onOpen: () {},
      ),
      focus: find.byType(ActivityLine),
      clipFinder: find.descendant(
        of: find.byType(ActivityLine),
        matching: find.byType(InkWell),
      ),
      radius: 0,
      why: 'ActivityLine',
    ),
    platforms: _rowPlatforms,
  );

  testOnPlatforms(
    'Agent row',
    (tester, platform) => check(
      tester,
      platform: platform,
      body: AgentRow(
        model: const AgentRowModel(
          goal: 'Summarize the advisories',
          state: AgentState.finished,
          runTime: Duration(seconds: 48),
          toolCount: 4,
        ),
        onShowDetails: () {},
      ),
      focus: find.byType(AgentRow),
      clipFinder: find.descendant(
        of: find.byType(AgentRow),
        matching: find.byType(InkWell),
      ),
      radius: 0,
      why: 'AgentRow',
    ),
    platforms: _rowPlatforms,
  );

  testOnPlatforms('Context row', (tester, platform) {
    const figures = ContextFigures(
      used: 124000,
      max: 200000,
      percent: 62,
      estimated: false,
      source: ContextSource.providerUsage,
    );
    return check(
      tester,
      platform: platform,
      body: ContextRow(
        figures: figures,
        level: contextLevelOf(figures),
        onOpen: () {},
      ),
      focus: find.byType(ContextRow),
      clipFinder: find.descendant(
        of: find.byType(ContextRow),
        matching: find.byType(InkWell),
      ),
      radius: 0,
      why: 'ContextRow',
    );
  }, platforms: _rowPlatforms);

  testOnPlatforms(
    'File checkpoints row',
    (tester, platform) => check(
      tester,
      platform: platform,
      body: FileCheckpointsRow(
        state: CheckpointsRowState.count,
        count: 3,
        onOpen: () {},
      ),
      focus: find.byType(FileCheckpointsRow),
      clipFinder: find.descendant(
        of: find.byType(FileCheckpointsRow),
        matching: find.byType(InkWell),
      ),
      radius: 0,
      why: 'FileCheckpointsRow',
    ),
    platforms: _rowPlatforms,
  );

  const done = [
    Subagent(
      id: 'a1',
      goal: 'Audit the dependency tree',
      count: 2,
      status: SubagentStatus.completed,
      duration: Duration(seconds: 12),
    ),
    Subagent(
      id: 'a2',
      goal: 'Summarize the advisories',
      index: 1,
      count: 2,
      status: SubagentStatus.completed,
      duration: Duration(seconds: 48),
    ),
  ];
  Widget card() => SubagentGroupCard(
    subagents: done,
    initiallyOpen: true,
    onShowDetails: (_) {},
  );

  testOnPlatforms(
    'Sub-agent group header',
    (tester, platform) => check(
      tester,
      platform: platform,
      body: card(),
      focus: find.byType(InkWell).first,
      clipFinder: find.byType(InkWell).first,
      radius: 8,
      why: 'sub-agent header',
    ),
    platforms: _rowPlatforms,
  );

  testOnPlatforms(
    'Sub-agent line',
    (tester, platform) => check(
      tester,
      platform: platform,
      body: card(),
      focus: find.byType(InkWell).at(1),
      clipFinder: find.byType(InkWell).at(1),
      radius: 0,
      why: 'sub-agent line',
    ),
    platforms: _rowPlatforms,
  );

  testOnPlatforms(
    'Tool-call JSON tree row',
    (tester, platform) => check(
      tester,
      platform: platform,
      body: const ToolJsonTree(
        text: '{"path": "go.sum", "options": {"recursive": true}}',
      ),
      focus: find.byType(InkWell).first,
      clipFinder: find.byType(InkWell).first,
      radius: 0,
      why: 'JSON tree row',
    ),
    platforms: _rowPlatforms,
  );

  testOnPlatforms(
    'Restart banner',
    (tester, platform) => check(
      tester,
      platform: platform,
      body: ServerRestartBanner.restarting(onTap: () {}),
      focus: find.byType(ServerRestartBanner),
      clipFinder: find.descendant(
        of: find.byType(ServerRestartBanner),
        matching: find.byType(InkWell),
      ),
      radius: 0,
      why: 'restart banner',
    ),
    platforms: _rowPlatforms,
  );

  testOnPlatforms(
    'Working-folder row',
    (tester, platform) => check(
      tester,
      platform: platform,
      body: WorkingDirectoryRow(
        folderName: 'demo',
        path: '/home/me/demo',
        branch: 'main',
        serverDefault: true,
        onTap: () {},
      ),
      focus: find.byType(WorkingDirectoryRow),
      clipFinder: find.descendant(
        of: find.byType(WorkingDirectoryRow),
        matching: find.byType(InkWell),
      ),
      radius: 10,
      why: 'working-folder row',
    ),
    platforms: _rowPlatforms,
  );

  for (final below in [false, true]) {
    testOnPlatforms(
      'Working-folder line${below ? ' (full width)' : ''}',
      (tester, platform) => check(
        tester,
        platform: platform,
        body: WorkingDirectoryLine(
          title: 'Weekly planning',
          folderName: 'api',
          branch: 'main',
          belowBar: below,
          onTap: () {},
        ),
        focus: find.byType(WorkingDirectoryLine),
        clipFinder: find.descendant(
          of: find.byType(WorkingDirectoryLine),
          matching: find.byType(InkWell),
        ),
        radius: 0,
        why: 'working-folder line',
      ),
      platforms: _rowPlatforms,
    );
  }

  for (final selected in [false, true]) {
    testOnPlatforms(
      'Kanban card${selected ? ', selected' : ''}',
      (tester, platform) => check(
        tester,
        platform: platform,
        body: KanbanCard(
          task: const KanbanTask(
            id: 't_1a2b3c',
            title: 'Draft the weekly report',
            status: 'todo',
          ),
          selected: selected,
          onTap: () {},
        ),
        focus: find.byType(KanbanCard),
        clipFinder: find.descendant(
          of: find.byType(KanbanCard),
          matching: find.byType(InkWell),
        ),
        // Clears the selected card's 2 px border by 2 px.
        radius: selected ? 10 : 11,
        inset: selected ? 4 : 3,
        why: 'kanban card',
      ),
      platforms: _rowPlatforms,
    );
  }

  testOnPlatforms('FileRow: keyboard focus shows the ring, a click does not', (
    tester,
    platform,
  ) async {
    await _pump(
      tester,
      platform,
      SizedBox(
        width: 360,
        child: FileRow(
          model: const FileRowModel(name: 'src', isFolder: true),
          onTap: () {},
        ),
      ),
    );
    await _focus(tester, find.byType(FileRow));
    expect(_ringFinder, findsOneWidget, reason: 'keyboard focus');
    await tester.tap(find.byType(FileRow));
    await tester.pumpAndSettle();
    expect(_ringFinder, findsNothing, reason: 'after a pointer click');
    await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    expect(_ringFinder, findsOneWidget, reason: 'the next key press');
  }, platforms: _rowPlatforms);

  testOnPlatforms('GroupedActionRow: a click shows no ring', (
    tester,
    platform,
  ) async {
    await _pump(
      tester,
      platform,
      SizedBox(
        width: 360,
        child: GroupedSection(
          children: [
            GroupedActionRow(
              title: 'Restart',
              icon: AppIcons.refresh,
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.byType(GroupedActionRow));
    await tester.pumpAndSettle();
    expect(_ringFinder, findsNothing);
  }, platforms: _rowPlatforms);
}

/// The platforms whose sidebar rows are `SidebarRow`s (a Mac has its own).
const _sidebarPlatforms = [
  TargetPlatform.iOS,
  TargetPlatform.android,
  TargetPlatform.linux,
  TargetPlatform.windows,
];

/// The platforms whose thread row has an inline More button of its own.
const _inlineMorePlatforms = [
  TargetPlatform.android,
  TargetPlatform.linux,
  TargetPlatform.windows,
];

const _macOnly = [TargetPlatform.macOS];

/// The ink well of the first [T] on screen.
Finder _inkOf(Type t) => find
    .descendant(of: find.byType(t).first, matching: find.byType(InkWell))
    .first;

/// Gives the row's own ink well primary focus (the nearest focus node above
/// the row's content), not a button inside the row.
Future<void> _focusInk(WidgetTester tester, Finder ink) async {
  final content = find.descendant(of: ink, matching: find.byType(Padding));
  Focus.of(tester.element(content.first)).requestFocus();
  await tester.pumpAndSettle();
}

Widget _sidebarThread({bool housekeeping = true}) => ChangeNotifierProvider(
  create: (_) => AuthController(),
  child: SizedBox(
    width: 300,
    height: 500,
    child: ThreadSidebar(
      threads: [
        ChatThread(
          id: 'thread-1',
          title: 'Plan the release',
          updatedAt: DateTime(2026, 1, 2),
          remote: true,
        ),
      ],
      selectedId: 'thread-1',
      onSelect: (_) {},
      onNewThread: () {},
      housekeeping: housekeeping
          ? ThreadHousekeeping(
              repository: HermesChatRepository(FakeHermesServer().client().raw),
              threads: () => const [],
              profile: () => null,
              changed: () {},
              report: (_) {},
              removed: (_) {},
              history: (thread, {cancelled}) async => const [],
            )
          : null,
    ),
  ),
);

Widget _macThreadRow() => MacThreadRow(
  title: 'Plan the release',
  selected: true,
  onTap: () {},
  onArchive: () {},
  menuItems: (context) =>
      macThreadMenuItems(context.l10n, pinned: false, manageable: true),
  onAction: (_) {},
);

/// The sidebar rows of F.427, table A: the hand-rolled `InkWell` rows of the
/// thread list, search results, destinations and the Mac source list. Each
/// ring is 2 px, inside the row's edge (the row's radius, 8 or 6, less the
/// inset), on keyboard focus only.
void _sidebarRowTests() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  Widget rows(Widget Function(String title, bool selected) row) => Column(
    spacing: 4,
    children: [row('Plan the release', true), row('Fix the login test', false)],
  );

  Widget sidebarRow(String title, bool selected) => SidebarRow(
    selected: selected,
    onTap: () {},
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    child: Text(title),
  );

  Widget sidebarAction(String title, bool selected) => SidebarAction(
    icon: AppIcons.add,
    label: title,
    selected: selected,
    onTap: () {},
  );

  Widget macRow(String title, bool selected) => MacSourceListRow(
    icon: AppIcons.add,
    label: title,
    selected: selected,
    onTap: () {},
  );

  final macSearchHit = MacSearchHitRow(
    hit: searchHits.first,
    selected: true,
    onTap: () {},
  );

  testOnPlatforms(
    'SidebarRow',
    (tester, platform) => _checkInside(
      tester,
      platform: platform,
      body: rows(sidebarRow),
      focus: find.byType(SidebarRow).first,
      clipFinder: _inkOf(SidebarRow),
      radius: 6,
      why: 'SidebarRow',
    ),
    platforms: _sidebarPlatforms,
  );

  testOnPlatforms(
    'search hit row (a SidebarRow)',
    (tester, platform) => _checkInside(
      tester,
      platform: platform,
      body: SizedBox(
        height: 300,
        child: ThreadSearchResults(
          query: 'backup',
          status: ThreadSearchStatus.done,
          hits: searchHits,
          selectedId: 'thread-2',
          onOpen: (_) {},
        ),
      ),
      focus: find.byType(SidebarRow).first,
      clipFinder: _inkOf(SidebarRow),
      radius: 6,
      why: 'search hit row',
    ),
    platforms: _sidebarPlatforms,
  );

  testOnPlatforms(
    'SidebarAction',
    (tester, platform) => _checkInside(
      tester,
      platform: platform,
      body: rows(sidebarAction),
      focus: find.byType(SidebarAction).first,
      clipFinder: _inkOf(SidebarAction),
      radius: 6,
      why: 'SidebarAction',
    ),
    platforms: _sidebarPlatforms,
  );

  testOnPlatforms('thread row with its More button: the row focused', (
    tester,
    platform,
  ) async {
    await _pump(tester, platform, _still(_sidebarThread()));
    await tester.pumpAndSettle();
    final ink = _inkOf(SidebarRow);
    await _focusInk(tester, ink);
    expect(tester.getRect(_ringFinder), tester.getRect(ink));
    expectInsideRow(tester, tester.getRect(ink), radius: 6, why: 'thread row');
  }, platforms: _inlineMorePlatforms);

  testOnPlatforms(
    'thread row with its More button: the button focused, no row ring',
    (tester, platform) async {
      await _pump(tester, platform, _still(_sidebarThread()));
      await tester.pumpAndSettle();
      expect(find.byType(ThreadActionsButton), findsOneWidget);
      await _focus(tester, find.byType(ThreadActionsButton));
      expect(
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<ThreadActionsButton>(),
        isNotNull,
        reason: 'the More button has the focus',
      );
      expect(_ringFinder, findsNothing);
    },
    platforms: _inlineMorePlatforms,
  );

  testOnPlatforms(
    'MacSourceListTile (destination row)',
    (tester, platform) => _checkInside(
      tester,
      platform: platform,
      body: rows(macRow),
      focus: find.byType(MacSourceListRow).first,
      clipFinder: _inkOf(MacSourceListTile),
      radius: 4,
      why: 'MacSourceListTile',
    ),
    platforms: _macOnly,
  );

  testOnPlatforms(
    'MacSourceListTile (recent search row)',
    (tester, platform) => _checkInside(
      tester,
      platform: platform,
      body: SizedBox(
        height: 300,
        child: MacSearchResults(
          query: '',
          status: ThreadSearchStatus.done,
          hits: const [],
          scope: ThreadSearchScope.profile,
          recent: const ['backup', 'release notes'],
          onOpen: (_) {},
          onPickRecent: (_) {},
        ),
      ),
      focus: find.byType(MacSourceListTile).first,
      clipFinder: _inkOf(MacSourceListTile),
      radius: 4,
      why: 'recent search row',
    ),
    platforms: _macOnly,
  );

  testOnPlatforms('Mac thread row: the row focused', (tester, platform) async {
    await _pump(
      tester,
      platform,
      _still(SizedBox(width: 260, child: _macThreadRow())),
    );
    final ink = _inkOf(MacSourceListTile);
    await _focusInk(tester, ink);
    expect(tester.getRect(_ringFinder), tester.getRect(ink));
    expectInsideRow(
      tester,
      tester.getRect(ink),
      radius: 4,
      why: 'Mac thread row',
    );
  }, platforms: _macOnly);

  for (final button in [NamedIconButton, NamedPopupMenuButton<ThreadAction>]) {
    testOnPlatforms('Mac thread row: the $button focused, no row ring', (
      tester,
      platform,
    ) async {
      await _pump(
        tester,
        platform,
        _still(SizedBox(width: 260, child: _macThreadRow())),
      );
      // The row shows its buttons, and so lets them take focus, while the
      // pointer is over it.
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.byType(MacThreadRow)));
      await tester.pumpAndSettle();
      await _focus(tester, find.byType(button));
      var inButton = false;
      FocusManager.instance.primaryFocus?.context?.visitAncestorElements((e) {
        inButton = e.widget is ButtonStyleButton;
        return !inButton;
      });
      expect(inButton, isTrue, reason: 'a button of the row has the focus');
      expect(_ringFinder, findsNothing);
    }, platforms: _macOnly);
  }

  testOnPlatforms(
    'MacSearchHitRow',
    (tester, platform) => _checkInside(
      tester,
      platform: platform,
      body: macSearchHit,
      focus: find.byType(MacSearchHitRow),
      clipFinder: _inkOf(MacSearchHitRow),
      radius: 4,
      why: 'MacSearchHitRow',
    ),
    platforms: _macOnly,
  );

  // A pointer press focuses an ink well too, and shows no ring; the next key
  // press shows it again.
  void keyboardOnly(
    String name,
    Widget body,
    Finder row,
    List<TargetPlatform> platforms,
  ) => testOnPlatforms(
    '$name: keyboard focus shows the ring, a click does not',
    (tester, platform) async {
      await _pump(tester, platform, _still(SizedBox(width: 360, child: body)));
      await _focus(tester, row);
      expect(_ringFinder, findsOneWidget, reason: 'keyboard focus');
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(_ringFinder, findsNothing, reason: 'after a pointer click');
      await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(_ringFinder, findsOneWidget, reason: 'the next key press');
    },
    platforms: platforms,
  );

  keyboardOnly(
    'SidebarRow',
    rows(sidebarRow),
    find.byType(SidebarRow).first,
    _sidebarPlatforms,
  );
  keyboardOnly(
    'SidebarAction',
    rows(sidebarAction),
    find.byType(SidebarAction).first,
    _sidebarPlatforms,
  );
  keyboardOnly(
    'MacSourceListTile',
    rows(macRow),
    find.byType(MacSourceListRow).first,
    _macOnly,
  );
  keyboardOnly(
    'MacSearchHitRow',
    macSearchHit,
    find.byType(MacSearchHitRow),
    _macOnly,
  );
}

void _ignore(AttachOrigin _) {}

void _ignoreTap() {}

/// The iOS pull-down trigger of [AdaptivePopupMenuButton] with a custom child
/// (F.441), as each of its five callers builds it: the ring follows the shape
/// the caller paints, outside it for the pill, the subtitle and the account
/// footer, inside it for the value row and the filter chip.
void _popupTriggerTests() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  PopupCaller caller(String name) =>
      popupCallers.singleWhere((c) => c.name == name);

  Future<void> pumpCaller(
    WidgetTester tester,
    PopupCaller caller, {
    double textScale = 1,
  }) => _pump(
    tester,
    TargetPlatform.iOS,
    textScale == 1
        ? caller.build()
        : Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(textScale)),
              child: caller.build(),
            ),
          ),
  );

  for (final scale in [1.0, 3.0]) {
    testWidgets('log level pill: outside, a stadium at text ${scale}x', (
      tester,
    ) async {
      final pill = caller('log level pill');
      await pumpCaller(tester, pill, textScale: scale);
      await _focus(tester, pill.popup);
      final shape = find
          .descendant(
            of: pill.popup,
            matching: find.byWidgetPredicate(
              (w) => w is DecoratedBox && w.decoration is ShapeDecoration,
            ),
          )
          .first;
      expectRingHugs(
        _ringBand(tester),
        _painted(tester, shape),
        reason: 'the ring is a stadium round the painted pill',
      );
    });
  }

  testWidgets('settings subtitle: outside, radius 4, in 4 pt of room', (
    tester,
  ) async {
    final subtitle = caller('settings subtitle menu');
    await pumpCaller(tester, subtitle);
    await _focus(tester, subtitle.popup);
    final row = tester.getRect(subtitle.child);
    expectRingHugs(_ringBand(tester), (row, 4), reason: 'the subtitle row');
    final room = tester.getRect(
      find.ancestor(of: subtitle.popup, matching: find.byType(Padding)).first,
    );
    final bounds = _ringBand(tester).getBounds();
    expect(room.inflate(0.01).contains(bounds.topLeft), isTrue);
    expect(room.inflate(0.01).contains(bounds.bottomRight), isTrue);
  });

  testWidgets('grouped value row: inside, 2 px within the row', (tester) async {
    final value = caller('grouped value row');
    await pumpCaller(tester, value);
    await _focus(tester, value.popup);
    final row = tester.getRect(value.child);
    expect(tester.getRect(_ringFinder), row, reason: 'wraps the whole row');
    expectInsideClip(tester, row, why: 'value row');
    // The iOS section radius (12) less the inset.
    expect(_ring(tester).$2.radius, 10, reason: 'value row ring radius');
  });

  for (final scale in [1.0, 3.0]) {
    testWidgets('kanban filter chip: inside the painted chip at ${scale}x', (
      tester,
    ) async {
      final chip = caller('kanban filter chip');
      await pumpCaller(tester, chip, textScale: scale);
      await _focus(tester, chip.popup);
      final painted = tester.getRect(
        find
            .descendant(of: find.byType(Chip), matching: find.byType(Material))
            .first,
      );
      expect(tester.getRect(_ringFinder), painted, reason: 'the chip itself');
      expectInsideClip(tester, painted, why: 'chip');
      // The chip's own radius (8) less the inset.
      expect(_ring(tester).$2.radius, 6, reason: 'chip ring radius');
    });
  }

  testWidgets('account footer: outside, radius 8', (tester) async {
    final footer = caller('account footer');
    await pumpCaller(tester, footer);
    await _focus(tester, footer.popup);
    expectRingHugs(_ringBand(tester), (
      tester.getRect(footer.child),
      8,
    ), reason: 'the footer');
  });
}
