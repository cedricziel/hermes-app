import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart'
    show InMemoryChatController;
import 'package:flutter_chat_ui/flutter_chat_ui.dart' show Chat;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/chat/activity/widgets/needs_you_dock.dart';
import 'package:hermes_app/src/chat/activity/widgets/needs_you_models.dart';
import 'package:hermes_app/src/chat/widgets/chat_composer.dart';
import 'package:hermes_app/src/chat/widgets/chat_thread_view.dart';
import 'package:provider/provider.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart'
    show ComposerHeightNotifier;

import '../../support/fake_attachment_source.dart';

const _billing = NeedsYouItem(
  id: 'billing',
  kind: NeedsYouKind.billing,
  body: BillingBodyModel(
    code: 'WDJB-MJHT',
    host: 'verify.example.com',
    openable: true,
  ),
  actions: {NeedsYouAction.open, NeedsYouAction.copy},
);

const _model = NeedsYouDockModel(items: [_billing]);

/// A thread view with the dock the composer's box builds, and what the
/// tests need to see around it.
Future<void> _pump(
  WidgetTester tester, {
  NeedsYouDockBuilder? dock,
  Widget? queueView,
  Size size = const Size(400, 800),
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final chat = InMemoryChatController();
  final composer = TextEditingController();
  final focus = FocusNode();
  final latest = ValueNotifier<String?>(null);
  for (final dispose in [
    chat.dispose,
    composer.dispose,
    focus.dispose,
    latest.dispose,
  ]) {
    addTearDown(dispose);
  }
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ChatThreadView(
          thread: null,
          chatController: chat,
          composerController: composer,
          composerFocus: focus,
          attachments: const [],
          attachmentSource: FakeAttachmentSource(),
          onAddAttachments: (_) {},
          onRemoveAttachment: (_) {},
          onSend: (_) {},
          onPickStarter: (_) {},
          latestReplyId: latest,
          welcome: false,
          dock: dock,
          queueView: queueView,
        ),
      ),
    ),
  );
  await tester.pump();
}

NeedsYouDockBuilder _static(NeedsYouDockModel model, {List<bool>? compacts}) =>
    (context, compact) {
      compacts?.add(compact);
      return NeedsYouDock(
        model: NeedsYouDockModel(items: model.items, compact: compact),
      );
    };

double _composerHeight(WidgetTester tester) => tester
    .element(find.byType(ChatComposer))
    .read<ComposerHeightNotifier>()
    .height;

void main() {
  testWidgets('the dock sits directly above the composer', (tester) async {
    await _pump(tester, dock: _static(_model));
    final dock = tester.getRect(find.byType(NeedsYouDock));
    final composer = tester.getRect(find.byType(ChatComposer));
    expect(dock.bottom, moreOrLessEquals(composer.top, epsilon: 0.5));
    expect(dock.height, lessThan(400), reason: 'the card wraps its content');
    expect(find.byKey(const Key('needs-you-dock')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the dock moves with the composer', (tester) async {
    await _pump(tester, dock: _static(_model));
    final before = tester.getRect(find.byType(ChatComposer));
    await _pump(
      tester,
      dock: _static(_model),
      queueView: const SizedBox(height: 60, child: Text('queued')),
    );
    final after = tester.getRect(find.byType(ChatComposer));
    expect(after.height, greaterThan(before.height));
    final dock = tester.getRect(find.byType(NeedsYouDock));
    expect(dock.bottom, moreOrLessEquals(after.top, epsilon: 0.5));
  });

  testWidgets('the transcript clears the dock as well as the composer', (
    tester,
  ) async {
    await _pump(tester);
    final without = _composerHeight(tester);
    await _pump(tester, dock: _static(_model));
    final dock = tester.getRect(find.byType(NeedsYouDock));
    expect(_composerHeight(tester) - without, moreOrLessEquals(dock.height));
  });

  testWidgets('nothing is drawn between the header and the transcript', (
    tester,
  ) async {
    await _pump(tester, dock: _static(_model));
    expect(find.byKey(const Key('chat-activity-strip')), findsNothing);
    expect(tester.getTopLeft(find.byType(Chat)).dy, 0);
  });

  testWidgets('a chat with no request shows no dock', (tester) async {
    await _pump(tester, dock: _static(const NeedsYouDockModel(items: [])));
    expect(find.byKey(const Key('needs-you-dock')), findsNothing);
  });

  testWidgets('a keyboard that leaves a small phone little room collapses '
      'the card', (tester) async {
    final compacts = <bool>[];
    await _pump(tester, dock: _static(_model, compacts: compacts));
    expect(compacts.last, isFalse);
    expect(find.byKey(const Key('needs-you-summary')), findsNothing);

    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.resetViewInsets);
    tester.view.physicalSize = const Size(375, 667);
    await tester.pump();
    expect(compacts.last, isTrue);
    expect(find.byKey(const Key('needs-you-summary')), findsOneWidget);
  });
}
