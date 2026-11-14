import 'package:flutter/material.dart';
import 'package:hermes_app/src/chat/activity/widgets/activity_panel.dart';
import 'package:hermes_app/src/chat/activity/widgets/needs_you_bodies.dart';
import 'package:hermes_app/src/chat/activity/widgets/needs_you_dock.dart';
import 'package:hermes_app/src/chat/activity/widgets/needs_you_models.dart';
import 'package:hermes_app/src/chat/widgets/chat_header.dart';
import 'package:hermes_app/src/chat/widgets/mac_chat_toolbar.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:widgetbook/widgetbook.dart';

import 'fixtures.dart';
import 'frame.dart';

/// The dock with working paging, since the model holds the shown index.
class _Demo extends StatefulWidget {
  const _Demo({
    required this.items,
    this.shown = 0,
    this.compact = false,
    this.answer,
    this.offline = false,
  });

  final List<NeedsYouItem> items;
  final int shown;
  final bool compact, offline;
  final NeedsYouAnswer? answer;

  @override
  State<_Demo> createState() => _DemoState();
}

class _DemoState extends State<_Demo> {
  late int shown = widget.shown;

  NeedsYouItem _styled(NeedsYouItem item) => NeedsYouItem(
    id: item.id,
    kind: item.kind,
    body: item.body,
    actions: item.actions,
    answer: widget.answer ?? item.answer,
    offline: widget.offline,
  );

  @override
  Widget build(BuildContext context) => NeedsYouDock(
    model: NeedsYouDockModel(
      items: [for (final item in widget.items) _styled(item)],
      shown: shown,
      compact: widget.compact,
      onShow: (index) => setState(() => shown = index),
      onCopy: (_) {},
      onOpen: (_, _) {},
      onSkip: (_, _) {},
      onContinue: (_) {},
      onReopen: (_) {},
    ),
  );
}

Widget _dock(
  List<NeedsYouItem> items, {
  int shown = 0,
  NeedsYouAnswer? answer,
  bool offline = false,
}) => frame(
  _Demo(items: items, shown: shown, answer: answer, offline: offline),
  maxWidth: 720,
);

Widget _scaled(Widget child, [double scale = 2]) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child,
  ),
);

/// A 375 x 667 phone with the keyboard open: a transcript stand-in, the dock,
/// a composer stand-in and a 260 pt keyboard.
Widget _smallPhone(List<NeedsYouItem> items, {required bool collapse}) =>
    Builder(
      builder: (context) {
        final base = MediaQuery.of(context);
        const size = Size(375, 667);
        final media = base.copyWith(
          size: size,
          viewInsets: const EdgeInsets.only(bottom: 260),
        );
        final scheme = Theme.of(context).colorScheme;
        return Align(
          alignment: Alignment.topLeft,
          child: SizedBox.fromSize(
            size: size,
            child: MediaQuery(
              data: media,
              child: Builder(
                builder: (context) => Column(
                  children: [
                    Expanded(
                      child: Container(
                        color: scheme.surface,
                        alignment: Alignment.center,
                        child: const Text('Transcript'),
                      ),
                    ),
                    _Demo(
                      items: items,
                      compact: collapse && needsYouCompactFor(media),
                    ),
                    Container(
                      height: 56,
                      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: scheme.outline),
                        borderRadius: BorderRadius.circular(kHermesRadius),
                      ),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: const Text('Message'),
                    ),
                    Container(
                      height: 260,
                      color: scheme.surfaceContainerHighest,
                      alignment: Alignment.center,
                      child: const Text('Keyboard'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

WidgetbookNode needsYouDockNode() => WidgetbookComponent(
  name: 'NeedsYouDock',
  useCases: [
    ...onEachPlatform('Billing', (_) => _dock([needsYouBilling])),
    ...onEachPlatform(
      'Billing, invalid link',
      (_) => _dock([needsYouBillingInvalidLink]),
    ),
    ...onEachPlatform(
      'Connector, one target',
      (_) => _dock([needsYouConnectorOne]),
    ),
    ...onEachPlatform(
      'Connector, three targets and a deadline',
      (_) => _dock([needsYouConnectorThree]),
    ),
    WidgetbookUseCase(
      name: 'Reclaimed',
      builder: (_) => _dock([needsYouReclaimed]),
    ),
    WidgetbookUseCase(
      name: 'Restore failed',
      builder: (_) => _dock([needsYouRestoreFailed]),
    ),
    ...onEachPlatform(
      '1 of 3',
      (_) =>
          _dock([needsYouConnectorThree, needsYouBilling, needsYouReclaimed]),
    ),
    ...onEachPlatform(
      '2 of 3',
      (_) => _dock([
        needsYouConnectorThree,
        needsYouBilling,
        needsYouReclaimed,
      ], shown: 1),
    ),
    WidgetbookUseCase(
      name: 'Sending',
      builder: (_) =>
          _dock([needsYouConnectorOne], answer: NeedsYouAnswer.sending),
    ),
    WidgetbookUseCase(
      name: 'Unconfirmed',
      builder: (_) =>
          _dock([needsYouConnectorOne], answer: NeedsYouAnswer.unconfirmed),
    ),
    WidgetbookUseCase(
      name: 'Refused',
      builder: (_) =>
          _dock([needsYouConnectorOne], answer: NeedsYouAnswer.refused),
    ),
    WidgetbookUseCase(
      name: 'Offline, connector',
      builder: (_) => _dock([needsYouConnectorThree], offline: true),
    ),
    WidgetbookUseCase(
      name: 'Offline, billing and connector',
      builder: (_) => frame(
        Column(
          children: [
            _Demo(items: const [needsYouBilling], offline: true),
            _Demo(items: const [needsYouConnectorOne], offline: true),
          ],
        ),
        maxWidth: 720,
      ),
    ),
    WidgetbookUseCase(
      name: 'Keyboard open on a small phone, collapsed',
      builder: (_) => _smallPhone([
        needsYouConnectorThree,
        needsYouBilling,
      ], collapse: true),
    ),
    WidgetbookUseCase(
      name: 'Keyboard open on a small phone, one target collapsed',
      builder: (_) => _smallPhone([needsYouConnectorOne], collapse: true),
    ),
    WidgetbookUseCase(
      name: 'Keyboard open on a small phone, billing collapsed',
      builder: (_) => _smallPhone([needsYouBilling], collapse: true),
    ),
    WidgetbookUseCase(
      name: 'Keyboard open on a small phone, not collapsed',
      builder: (_) => _smallPhone([needsYouConnectorThree], collapse: false),
    ),
    for (final (name, item) in [
      ('Billing', needsYouBilling),
      ('Billing, invalid link', needsYouBillingInvalidLink),
      ('Connector, three targets', needsYouConnectorThree),
      ('Reclaimed', needsYouReclaimed),
      ('Restore failed', needsYouRestoreFailed),
    ])
      WidgetbookUseCase(
        name: '$name, largest text',
        builder: (_) => _scaled(
          _dock([item, if (item.id == 'connector-three') needsYouBilling]),
        ),
      ),
    for (final (name, item) in [
      ('Billing', needsYouBilling),
      ('Connector, three targets', needsYouConnectorThree),
      ('Restore failed', needsYouRestoreFailed),
    ])
      WidgetbookUseCase(
        name: '$name, 3x text',
        builder: (_) => _scaled(
          _dock([item, if (item.id == 'connector-three') needsYouBilling]),
          3,
        ),
      ),
    for (final scale in [1.3, 2.0])
      WidgetbookUseCase(
        name: 'Restore failed, 1 of 3, ${scale}x text',
        builder: (_) => _scaled(
          _dock([needsYouRestoreFailed, needsYouBilling, needsYouReclaimed]),
          scale,
        ),
      ),
    WidgetbookUseCase(
      name: 'Connector with an answer lost, largest text',
      builder: (_) => _scaled(
        _dock([needsYouConnectorOne], answer: NeedsYouAnswer.unconfirmed),
      ),
    ),
    WidgetbookUseCase(
      name: 'Dark, connector',
      builder: (_) => Theme(
        data: buildHermesDarkTheme(),
        child: Material(
          color: buildHermesDarkTheme().colorScheme.surface,
          child: _dock([needsYouConnectorThree, needsYouBilling]),
        ),
      ),
    ),
  ],
);

Widget _body(Widget body) => frame(
  Padding(padding: const EdgeInsets.all(16), child: body),
  maxWidth: 480,
);

WidgetbookNode needsYouBodiesNode() => WidgetbookFolder(
  name: 'NeedsYou bodies',
  children: [
    WidgetbookComponent(
      name: 'BillingNeedsYouBody',
      useCases: [
        WidgetbookUseCase(
          name: 'Valid link',
          builder: (_) => _body(
            BillingNeedsYouBody(
              model: needsYouBilling.body as BillingBodyModel,
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'Invalid link',
          builder: (_) => _body(
            BillingNeedsYouBody(
              model: needsYouBillingInvalidLink.body as BillingBodyModel,
            ),
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'ConnectorNeedsYouBody',
      useCases: [
        WidgetbookUseCase(
          name: 'One target',
          builder: (_) => _body(
            ConnectorNeedsYouBody(
              model: needsYouConnectorOne.body as ConnectorBodyModel,
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'Three targets, each with Open',
          builder: (_) => _body(
            ConnectorNeedsYouBody(
              model: needsYouConnectorThree.body as ConnectorBodyModel,
              onOpen: (_) {},
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'Three targets, Open disabled',
          builder: (_) => _body(
            ConnectorNeedsYouBody(
              model: needsYouConnectorThree.body as ConnectorBodyModel,
              onOpen: (_) {},
              openEnabled: false,
            ),
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'ReclaimNeedsYouBody',
      useCases: [
        WidgetbookUseCase(
          name: 'Reclaimed',
          builder: (_) => _body(
            ReclaimNeedsYouBody(
              model: needsYouReclaimed.body as ReclaimBodyModel,
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'Restore failed',
          builder: (_) => _body(
            ReclaimNeedsYouBody(
              model: needsYouRestoreFailed.body as ReclaimBodyModel,
              restoreFailed: true,
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'Notice line',
          builder: (_) => _body(
            const NeedsYouNoticeLine(
              text:
                  'Couldn\'t confirm your answer. It may have gone through; '
                  'check before trying again.',
            ),
          ),
        ),
      ],
    ),
  ],
);

Widget _header(int waiting, {required bool apple}) => Builder(
  builder: (context) => Theme(
    data: Theme.of(
      context,
    ).copyWith(platform: apple ? TargetPlatform.iOS : TargetPlatform.android),
    child: Material(
      color: Theme.of(context).colorScheme.surface,
      child: ChatHeader(
        thread: null,
        displayTitle: 'Weekly digest',
        onShowConnection: () {},
        onNewChat: () {},
        activityWaiting: waiting,
        onToggleActivity: () {},
      ),
    ),
  ),
);

Widget _macToolbar(int waiting) => Builder(
  builder: (context) => Theme(
    data: Theme.of(context).copyWith(platform: TargetPlatform.macOS),
    child: Align(
      alignment: Alignment.topCenter,
      child: MacChatToolbar(
        title: 'Weekly digest',
        subtitle: 'default · gpt-5',
        onNewChat: () {},
        onShowConnection: () {},
        onCopyTranscript: () {},
        activityWaiting: waiting,
        onToggleActivity: () {},
        searchQuery: '',
        searchActive: false,
        onSearchBegin: () {},
        onSearchChanged: (_) {},
        onSearchEnd: () {},
      ),
    ),
  ),
);

WidgetbookNode activityWaitingMarkerNode() => WidgetbookComponent(
  name: 'ActivityButton marker',
  useCases: [
    for (final waiting in [0, 1, 3]) ...[
      WidgetbookUseCase(
        name: '$waiting waiting, iOS header',
        builder: (_) => fill(_header(waiting, apple: true)),
      ),
      WidgetbookUseCase(
        name: '$waiting waiting, Material header',
        builder: (_) => fill(_header(waiting, apple: false)),
      ),
      WidgetbookUseCase(
        name: '$waiting waiting, Mac toolbar',
        builder: (_) => _macToolbar(waiting),
      ),
      WidgetbookUseCase(
        name: '$waiting waiting, button alone',
        builder: (_) => frame(
          ActivityButton(open: false, waiting: waiting, onPressed: () {}),
        ),
      ),
    ],
  ],
);
