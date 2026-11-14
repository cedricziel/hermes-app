import 'package:flutter/material.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/tools/toolset_copy.dart';
import 'package:hermes_app/src/tools/toolset_risk.dart';
import 'package:hermes_app/src/tools/widgets/risk_note.dart';
import 'package:hermes_app/src/tools/widgets/status_chip.dart';
import 'package:hermes_app/src/tools/widgets/toolset_header.dart';
import 'package:hermes_app/src/tools/widgets/toolset_row.dart';
import 'package:hermes_app/src/tools/widgets/tools_list_footer.dart';
import 'package:hermes_app/src/widgets/app_banner.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';
import 'package:hermes_app/src/widgets/state_message.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

Widget _at(double scale, Widget Function() child) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child(),
  ),
);

void _noop() {}

/// A toolset's row as the list builds it from the table of built-in names.
ToolsetRowView _view(
  AppLocalizations l10n,
  String name, {
  bool enabled = false,
  bool needsSetup = false,
  int actions = 3,
  ToolsetRowPhase phase = ToolsetRowPhase.idle,
  bool showTryAgain = false,
  ToolsetRowError? error,
  bool selected = false,
}) => ToolsetRowView(
  name: toolsetLabel(l10n, name),
  sentence: toolsetSentence(l10n, name) ?? '',
  enabled: enabled,
  riskLine: toolsetRisk(name) != null,
  needsSetup: needsSetup,
  actionCount: actions,
  phase: phase,
  showTryAgain: showTryAgain,
  error: error,
  selected: selected,
);

/// A row whose switch moves when it is idle, so the catalog can be played
/// with; a row in another phase keeps its position, as the real one does.
class _LiveRow extends StatefulWidget {
  const _LiveRow(this.view);

  final ToolsetRowView view;

  @override
  State<_LiveRow> createState() => _LiveRowState();
}

class _LiveRowState extends State<_LiveRow> {
  late bool _enabled = widget.view.enabled;

  @override
  void didUpdateWidget(_LiveRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Moving to another use case reuses this state.
    _enabled = widget.view.enabled;
  }

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    return ToolsetRow(
      view: ToolsetRowView(
        name: view.name,
        sentence: view.sentence,
        enabled: _enabled,
        riskLine: view.riskLine,
        needsSetup: view.needsSetup,
        actionCount: view.actionCount,
        phase: view.phase,
        showTryAgain: view.showTryAgain,
        error: view.error,
        selected: view.selected,
        unknownPlugin: view.unknownPlugin,
      ),
      onOpen: _noop,
      onChanged: (value) => setState(() => _enabled = value),
      onTryAgain: _noop,
    );
  }
}

Widget _page(List<Widget> children) =>
    Scaffold(body: GroupedListView(children: children));

Widget _rows(List<ToolsetRowView> views) => _page([
  GroupedSection(children: [for (final view in views) _LiveRow(view)]),
]);

WidgetbookUseCase _rowCase(
  String name,
  List<ToolsetRowView> Function(AppLocalizations l10n) views, {
  double scale = 1,
}) => WidgetbookUseCase(
  name: name,
  builder: (context) => _at(scale, () => _rows(views(context.l10n))),
);

ToolsetRowError _refused() => const ToolsetRowError(
  ToolsetRowErrorKind.refused,
  'Terminal can only be switched on for the default profile.',
);

const _pluginView = ToolsetRowView(
  name: 'Weather lookup',
  sentence: 'get_forecast, get_alerts, get_radar_image',
  enabled: false,
  actionCount: 3,
  unknownPlugin: true,
);

WidgetbookNode _rowComponent() => WidgetbookComponent(
  name: 'ToolsetRow',
  useCases: [
    _rowCase('Off', (l) => [_view(l, 'memory')]),
    _rowCase('On', (l) => [_view(l, 'memory', enabled: true)]),
    _rowCase(
      'On, needs setup',
      (l) => [_view(l, 'image_gen', enabled: true, needsSetup: true)],
    ),
    _rowCase('Off, needs setup', (l) => [_view(l, 'web', needsSetup: true)]),
    _rowCase('Risky, asks first (terminal)', (l) => [_view(l, 'terminal')]),
    _rowCase(
      'Risky, explains (files)',
      (l) => [_view(l, 'file', enabled: true, actions: 1)],
    ),
    _rowCase(
      'Risky and needs setup',
      (l) => [_view(l, 'computer_use', needsSetup: true, actions: 12)],
    ),
    _rowCase('Plugin toolset, server text', (_) => [_pluginView]),
    _rowCase('No actions known', (l) => [_view(l, 'tts', actions: 0)]),
    _rowCase(
      'Saving',
      (l) => [
        _view(l, 'terminal', enabled: true, phase: ToolsetRowPhase.saving),
      ],
    ),
    _rowCase(
      'Failed, Hermes text',
      (l) => [_view(l, 'terminal', error: _refused())],
    ),
    _rowCase(
      'Not allowed',
      (l) => [
        _view(
          l,
          'memory',
          error: ToolsetRowError(
            ToolsetRowErrorKind.notAllowed,
            l.toolsErrorNotAllowed,
          ),
        ),
      ],
    ),
    _rowCase(
      'Failed offline',
      (l) => [
        _view(
          l,
          'file',
          error: ToolsetRowError(
            ToolsetRowErrorKind.offline,
            l.toolsErrorOffline(toolsetLabel(l, 'file')),
          ),
        ),
      ],
    ),
    _rowCase(
      'Failed, try again',
      (l) => [
        _view(
          l,
          'memory',
          error: ToolsetRowError(
            ToolsetRowErrorKind.failed,
            l.toolsErrorFailed(toolsetLabel(l, 'memory')),
          ),
        ),
      ],
    ),
    _rowCase(
      'Answer lost, checking',
      (l) => [
        _view(l, 'memory', enabled: true, phase: ToolsetRowPhase.checking),
      ],
    ),
    _rowCase(
      'Couldn\'t confirm, pull to refresh',
      (l) => [_view(l, 'memory', phase: ToolsetRowPhase.unconfirmed)],
    ),
    _rowCase(
      'Couldn\'t confirm, try again (desktop)',
      (l) => [
        _view(
          l,
          'memory',
          phase: ToolsetRowPhase.unconfirmed,
          showTryAgain: true,
        ),
      ],
    ),
    _rowCase(
      'Waiting for a confirmation',
      (l) => [
        _view(l, 'terminal', phase: ToolsetRowPhase.awaitingConfirmation),
      ],
    ),
    _rowCase(
      'Selected in a pane',
      (l) => [
        _view(l, 'web', needsSetup: true),
        _view(l, 'terminal', enabled: true, selected: true),
        _view(l, 'memory', enabled: true),
      ],
    ),
    _rowCase('Largest text, off', (l) => [_view(l, 'terminal')], scale: 3),
    _rowCase(
      'Largest text, on and needs setup',
      (l) => [_view(l, 'web', enabled: true, needsSetup: true)],
      scale: 3,
    ),
    _rowCase(
      'Largest text, saving',
      (l) => [
        _view(l, 'terminal', enabled: true, phase: ToolsetRowPhase.saving),
      ],
      scale: 3,
    ),
    _rowCase(
      'Largest text, failed',
      (l) => [
        _view(
          l,
          'file',
          error: ToolsetRowError(
            ToolsetRowErrorKind.offline,
            l.toolsErrorOffline(toolsetLabel(l, 'file')),
          ),
        ),
      ],
      scale: 3,
    ),
    _rowCase(
      'Twice the text, on',
      (l) => [_view(l, 'code_execution', enabled: true)],
      scale: 2,
    ),
    ...onEachPlatform(
      'Saving',
      (context) => _rows([
        _view(
          context.l10n,
          'terminal',
          enabled: true,
          phase: ToolsetRowPhase.saving,
        ),
        _view(context.l10n, 'memory', enabled: true),
      ]),
    ),
    ...onEachPlatform(
      'Couldn\'t confirm, try again',
      (context) => _rows([
        _view(
          context.l10n,
          'memory',
          phase: ToolsetRowPhase.unconfirmed,
          showTryAgain: true,
        ),
      ]),
    ),
  ],
);

WidgetbookNode _headerComponent() {
  Widget header(
    BuildContext context,
    String name, {
    bool enabled = false,
    bool needsSetup = false,
    bool saving = false,
    String? label,
  }) {
    final l10n = context.l10n;
    return frame(
      ToolsetHeader(
        name: label ?? toolsetLabel(l10n, name),
        sentence: toolsetSentence(l10n, name) ?? '',
        enabled: enabled,
        needsSetup: needsSetup,
        saving: saving,
        onChanged: (_) {},
      ),
    );
  }

  return WidgetbookComponent(
    name: 'ToolsetHeader',
    useCases: [
      WidgetbookUseCase(
        name: 'On',
        builder: (c) => header(c, 'memory', enabled: true),
      ),
      WidgetbookUseCase(name: 'Off', builder: (c) => header(c, 'memory')),
      WidgetbookUseCase(
        name: 'On, needs setup',
        builder: (c) => header(c, 'web', enabled: true, needsSetup: true),
      ),
      WidgetbookUseCase(
        name: 'Off, needs setup',
        builder: (c) => header(c, 'web', needsSetup: true),
      ),
      WidgetbookUseCase(
        name: 'Saving',
        builder: (c) => header(c, 'terminal', enabled: true, saving: true),
      ),
      WidgetbookUseCase(
        name: 'Long name',
        builder: (c) => header(
          c,
          'web',
          enabled: true,
          label: 'Web search, scraping and everything else about the web',
        ),
      ),
      for (final scale in [2.0, 3.0])
        WidgetbookUseCase(
          name: 'Largest text, ${scale.toInt()}x',
          builder: (c) => _at(
            scale,
            () => header(c, 'web', enabled: true, needsSetup: true),
          ),
        ),
      WidgetbookUseCase(
        name: 'Largest text, saving',
        builder: (c) =>
            _at(3, () => header(c, 'terminal', enabled: true, saving: true)),
      ),
      ...onEachPlatform(
        'Off, needs setup',
        (c) => header(c, 'web', needsSetup: true),
      ),
    ],
  );
}

WidgetbookNode _riskComponent() {
  Widget note(ToolsetRiskKind kind, {required bool confirm}) =>
      frame(RiskNote(kind: kind, confirmLevel: confirm));

  return WidgetbookComponent(
    name: 'RiskNote',
    useCases: [
      WidgetbookUseCase(
        name: 'Terminal (asks first)',
        builder: (_) => note(ToolsetRiskKind.runCommands, confirm: true),
      ),
      WidgetbookUseCase(
        name: 'Code execution (asks first)',
        builder: (_) => note(ToolsetRiskKind.runPrograms, confirm: true),
      ),
      WidgetbookUseCase(
        name: 'Files',
        builder: (_) => note(ToolsetRiskKind.changeFiles, confirm: false),
      ),
      WidgetbookUseCase(
        name: 'Computer use (asks first)',
        builder: (_) => note(ToolsetRiskKind.controlComputer, confirm: true),
      ),
      WidgetbookUseCase(
        name: 'Browser (asks first)',
        builder: (_) => note(ToolsetRiskKind.actOnWebPages, confirm: true),
      ),
      WidgetbookUseCase(
        name: 'Scheduled tasks and delegation',
        builder: (_) => note(ToolsetRiskKind.actOnItsOwn, confirm: false),
      ),
      WidgetbookUseCase(
        name: 'Discord admin',
        builder: (_) => note(ToolsetRiskKind.manageDiscord, confirm: false),
      ),
      WidgetbookUseCase(
        name: 'Largest text',
        builder: (_) =>
            _at(3, () => note(ToolsetRiskKind.controlComputer, confirm: true)),
      ),
      ...onEachPlatform(
        'Terminal',
        (_) => frame(
          const RiskNote(kind: ToolsetRiskKind.runCommands, confirmLevel: true),
        ),
      ),
    ],
  );
}

WidgetbookNode _chipComponent() => WidgetbookComponent(
  name: 'StatusChip',
  useCases: [
    for (final status in ToolsStatus.values)
      WidgetbookUseCase(
        name: switch (status) {
          ToolsStatus.ready => 'Ready',
          ToolsStatus.needsKey => 'Needs a key',
          ToolsStatus.needsSignIn => 'Needs a sign-in on the server',
          ToolsStatus.needsInstall => 'Needs install',
          ToolsStatus.needsSetup => 'Needs setup',
          ToolsStatus.unusable => 'Can\'t be used',
        },
        builder: (_) => frame(
          Align(alignment: Alignment.centerLeft, child: StatusChip(status)),
        ),
      ),
    WidgetbookUseCase(
      name: 'All',
      builder: (_) => frame(
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final status in ToolsStatus.values) StatusChip(status),
          ],
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Largest text, narrow',
      builder: (_) => _at(
        3,
        () => frame(
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusChip(ToolsStatus.needsSignIn),
              StatusChip(ToolsStatus.needsKey),
            ],
          ),
          maxWidth: 280,
        ),
      ),
    ),
  ],
);

AppBanner? _banner(BuildContext context, _ListBanner banner) {
  final l10n = context.l10n;
  Widget retry() =>
      TextButton(onPressed: () {}, child: Text(l10n.toolsTryAgain));
  return switch (banner) {
    _ListBanner.none => null,
    _ListBanner.loadFailed => AppBanner(
      tone: AppBannerTone.error,
      title: l10n.toolsBannerLoadFailedTitle,
      detail: l10n.toolsBannerLoadFailedDetail,
      action: retry(),
    ),
    _ListBanner.offline => AppBanner(
      tone: AppBannerTone.warning,
      icon: AppIcons.cloud,
      title: l10n.toolsBannerOfflineTitle,
      detail: l10n.toolsBannerOfflineDetail,
      action: retry(),
    ),
    _ListBanner.installer => AppBanner(
      tone: AppBannerTone.success,
      title: l10n.toolsBannerInstallerTitle(toolsetLabel(l10n, 'computer_use')),
      detail: l10n.toolsBannerInstallerDetail,
      action: TextButton(onPressed: () {}, child: Text(l10n.toolsBannerShow)),
    ),
  };
}

enum _ListBanner { none, loadFailed, offline, installer }

/// The list as the screen builds it: an optional banner, the groups the
/// toolsets fall into with empty ones left out, and the footer.
Widget _list(
  BuildContext context, {
  _ListBanner banner = _ListBanner.none,
  bool allOn = false,
}) {
  final l10n = context.l10n;
  ToolsetRowView v(
    String name, {
    bool enabled = false,
    bool needsSetup = false,
    int actions = 3,
  }) => _view(
    l10n,
    name,
    enabled: enabled,
    needsSetup: needsSetup,
    actions: actions,
  );
  final setup = [
    v('web', needsSetup: true, actions: 2),
    v('image_gen', enabled: true, needsSetup: true, actions: 1),
  ];
  final on = [
    v('terminal', enabled: true, actions: 4),
    v('file', enabled: true, actions: 6),
    v('memory', enabled: true, actions: 1),
    v('skills', enabled: true, actions: 3),
  ];
  final off = [
    v('browser', actions: 11),
    v('video_gen', actions: 1),
    v('tts', actions: 1),
    _pluginView,
  ];
  final all = [
    for (final view in [...setup, ...on, ...off])
      ToolsetRowView(
        name: view.name,
        sentence: view.sentence,
        enabled: true,
        riskLine: view.riskLine,
        actionCount: view.actionCount,
        unknownPlugin: view.unknownPlugin,
      ),
  ];
  Widget section(String? header, List<ToolsetRowView> views) => GroupedSection(
    header: header,
    children: [for (final view in views) _LiveRow(view)],
  );
  final top = _banner(context, banner);
  return _page([
    ?(top == null
        ? null
        : Padding(padding: const EdgeInsets.only(top: 12), child: top)),
    if (allOn)
      section(null, all)
    else ...[
      section(l10n.toolsNeedsSetup, setup),
      section(l10n.commonOn, on),
      section(l10n.commonOff, off),
    ],
    ToolsListFooter(onWhatsTheDifference: _noop),
  ]);
}

WidgetbookNode _listComponent() => WidgetbookComponent(
  name: 'Tools list states',
  useCases: [
    WidgetbookUseCase(name: 'Grouped', builder: _list),
    WidgetbookUseCase(name: 'All on', builder: (c) => _list(c, allOn: true)),
    WidgetbookUseCase(
      name: 'Loading',
      builder: (c) => fill(
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 12,
            children: [
              const CircularProgressIndicator.adaptive(),
              Text(c.l10n.toolsLoading),
            ],
          ),
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Empty',
      builder: (c) => StateMessage(
        title: c.l10n.toolsEmptyTitle,
        detail: c.l10n.toolsEmptyDetail,
      ),
    ),
    WidgetbookUseCase(
      name: 'Couldn\'t load',
      builder: (c) => _list(c, banner: _ListBanner.loadFailed),
    ),
    WidgetbookUseCase(
      name: 'Offline',
      builder: (c) => _list(c, banner: _ListBanner.offline),
    ),
    WidgetbookUseCase(
      name: 'Old server',
      builder: (c) => StateMessage(
        title: c.l10n.toolsOldServerTitle,
        detail: c.l10n.toolsOldServerDetail,
        action: OutlinedButton(
          onPressed: () {},
          child: Text(MaterialLocalizations.of(c).backButtonTooltip),
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Installer started',
      builder: (c) => _list(c, banner: _ListBanner.installer),
    ),
    WidgetbookUseCase(
      name: 'Footer',
      builder: (_) => frame(ToolsListFooter(onWhatsTheDifference: _noop)),
    ),
    WidgetbookUseCase(
      name: 'Grouped, largest text',
      builder: (c) => _at(3, () => _list(c)),
    ),
    WidgetbookUseCase(
      name: 'Offline, largest text',
      builder: (c) => _at(2, () => _list(c, banner: _ListBanner.offline)),
    ),
    WidgetbookUseCase(
      name: 'Old server, largest text',
      builder: (c) => _at(
        3,
        () => SingleChildScrollView(
          child: StateMessage(
            title: c.l10n.toolsOldServerTitle,
            detail: c.l10n.toolsOldServerDetail,
            action: OutlinedButton(
              onPressed: () {},
              child: Text(MaterialLocalizations.of(c).backButtonTooltip),
            ),
          ),
        ),
      ),
    ),
  ],
);

WidgetbookNode toolsNode() => WidgetbookFolder(
  name: 'Tools',
  children: [
    _rowComponent(),
    _headerComponent(),
    _riskComponent(),
    _chipComponent(),
    _listComponent(),
  ],
);
