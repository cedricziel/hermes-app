import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/tools/toolset_copy.dart';
import 'package:hermes_app/src/tools/tools_models.dart';
import 'package:hermes_app/src/tools/widgets/install_progress.dart';
import 'package:hermes_app/src/tools/widgets/provider_row.dart';
import 'package:hermes_app/src/tools/widgets/readiness_row.dart';
import 'package:hermes_app/src/tools/widgets/status_chip.dart';
import 'package:hermes_app/src/tools/widgets/tools_confirmation.dart';
import 'package:hermes_app/src/tools/widgets/tools_difference_sheet.dart';
import 'package:hermes_app/src/tools/widgets/tools_load_state.dart';
import 'package:hermes_app/src/tools/widgets/toolset_key_form.dart';
import 'package:hermes_app/src/tools/widgets/toolset_model_sheet.dart';
import 'package:hermes_app/src/widgets/disclosure_tile.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';
import 'host.dart';

Widget _at(double scale, Widget Function() child) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child(),
  ),
);

Widget _page(List<Widget> children) =>
    Scaffold(body: GroupedListView(children: children));

/// A provider as the fixtures below describe it, with invented names.
class _P {
  const _P(
    this.name,
    this.status, {
    this.badge,
    this.line,
    this.nous = false,
    this.hermes,
    this.fail = false,
  });

  final String name;
  final ToolsStatus status;
  final String? badge;
  final String? line;
  final bool nous;
  final String? hermes;
  final bool fail;
}

const _webProviders = [
  _P(
    'Brightfetch',
    ToolsStatus.ready,
    badge: 'paid',
    line: 'Search and extract',
  ),
  _P(
    'Quillsearch',
    ToolsStatus.needsKey,
    badge: 'paid',
    line: 'Search and extract',
  ),
  _P(
    'Openpage',
    ToolsStatus.needsSignIn,
    badge: 'subscription',
    line: 'Search and extract',
    nous: true,
  ),
  _P('Pagehound', ToolsStatus.needsInstall, line: 'Extract only'),
];

/// A group of provider rows where a tap moves the pick, so the catalog can be
/// played with.
class _PickGroup extends StatefulWidget {
  const _PickGroup(
    this.items, {
    this.picked = 0,
    this.header,
    this.footer,
    this.sectionPerRow = false,
  });

  final List<_P> items;
  final int picked;
  final String? header;
  final String? footer;
  final bool sectionPerRow;

  @override
  State<_PickGroup> createState() => _PickGroupState();
}

class _PickGroupState extends State<_PickGroup> {
  late int _picked = widget.picked;

  @override
  void didUpdateWidget(_PickGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    _picked = widget.picked;
  }

  ProviderRow _row(int index) {
    final item = widget.items[index];
    return ProviderRow(
      name: item.name,
      status: item.status,
      badge: item.badge,
      line: item.line,
      needsNousSignIn: item.nous,
      hermesText: item.hermes,
      commandsWillFail: item.fail && _picked == index,
      picked: _picked == index,
      onPick: () => setState(() => _picked = index),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sectionPerRow) {
      return Column(
        children: [
          for (final i in List.generate(widget.items.length, (i) => i))
            GroupedSection(
              children: [
                ProviderRow(
                  name: widget.items[i].name,
                  status: widget.items[i].status,
                  badge: widget.items[i].badge,
                  line: widget.items[i].line,
                  needsNousSignIn: widget.items[i].nous,
                  hermesText: widget.items[i].hermes,
                  picked: widget.picked == i,
                  onPick: () {},
                ),
              ],
            ),
        ],
      );
    }
    return GroupedSection(
      header: widget.header,
      footer: widget.footer,
      dividerIndent: ProviderRow.dividerIndent(context),
      children: [for (var i = 0; i < widget.items.length; i++) _row(i)],
    );
  }
}

Widget _group(
  List<_P> items, {
  int picked = 0,
  String? header,
  String? footer,
  bool sectionPerRow = false,
}) => _page([
  _PickGroup(
    items,
    picked: picked,
    header: header,
    footer: footer,
    sectionPerRow: sectionPerRow,
  ),
]);

const _backends = [
  _P('Local', ToolsStatus.ready, line: 'Run on the same machine as Hermes'),
  _P(
    'Docker',
    ToolsStatus.needsSetup,
    line: 'Run inside a container',
    hermes: 'The Docker daemon is not running.',
    fail: true,
  ),
  _P(
    'SSH',
    ToolsStatus.unusable,
    line: 'Run on another machine',
    hermes: 'No SSH host is configured.',
  ),
];

WidgetbookNode _providerRowComponent() => WidgetbookComponent(
  name: 'ProviderRow',
  useCases: [
    WidgetbookUseCase(
      name: 'Every status, not picked',
      builder: (_) => _group([
        for (final status in ToolsStatus.values)
          _P(
            'Provider ${status.index + 1}',
            status,
            line: 'Search and extract',
          ),
      ], picked: -1),
    ),
    WidgetbookUseCase(
      name: 'Every status, picked',
      builder: (_) => _page([
        _PickGroup([
          for (final status in ToolsStatus.values)
            _P(
              'Provider ${status.index + 1}',
              status,
              line: 'Search and extract',
            ),
        ], sectionPerRow: true),
      ]),
    ),
    WidgetbookUseCase(
      name: 'Badges, paid and subscription',
      builder: (_) => _group(_webProviders.sublist(0, 3), picked: 1),
    ),
    WidgetbookUseCase(
      name: 'Needs a sign-in on the server (note)',
      builder: (_) => _group([_webProviders[2], _webProviders[0]]),
    ),
    WidgetbookUseCase(
      name: 'Backend with Hermes\' text',
      builder: (_) => _group(_backends, picked: 0),
    ),
    WidgetbookUseCase(
      name: 'Picked backend that needs setup',
      builder: (_) => _group(_backends, picked: 1),
    ),
    WidgetbookUseCase(
      name: 'Long names and text',
      builder: (_) => _group(const [
        _P(
          'A provider with a very long name that has to wrap onto a second line',
          ToolsStatus.needsSignIn,
          badge: 'subscription',
          line: 'A tag line that is also long enough to need two lines on a phone',
          nous: true,
        ),
      ]),
    ),
    WidgetbookUseCase(
      name: 'Largest text, 2x',
      builder: (_) => _at(2, () => _group(_webProviders, picked: 2)),
    ),
    WidgetbookUseCase(
      name: 'Largest text, 3x',
      builder: (_) => _at(3, () => _group(_webProviders, picked: 2)),
    ),
    ...onEachPlatform('Group', (_) => _group(_webProviders, picked: 0)),
  ],
);

Widget _advanced(BuildContext context, {bool open = true}) {
  final l10n = context.l10n;
  Widget choice(String header, {String? footer}) =>
      _PickGroup(_webProviders, header: header, footer: footer);
  return _page([
    _PickGroup(
      _webProviders,
      header: l10n.toolsSetupHeader,
      footer: l10n.toolsSetupFooter,
    ),
    GroupedSection(
      children: [
        DisclosureTile(
          initiallyExpanded: open,
          title: Text(l10n.toolsSetupAdvancedTitle),
          shape: const Border(),
          collapsedShape: const Border(),
          children: const [],
        ),
      ],
    ),
    if (open) ...[
      choice(l10n.toolsSetupSearchHeader),
      choice(
        l10n.toolsSetupExtractHeader,
        footer: l10n.toolsSetupAdvancedFooter,
      ),
    ],
  ]);
}

Widget _section(BuildContext context, Widget row, {String? header}) => _page([
  GroupedSection(
    header: header ?? context.l10n.toolsSetupHeader,
    children: [row],
  ),
]);

WidgetbookNode _setupComponent() => WidgetbookComponent(
  name: 'Set up and terminal backends',
  useCases: [
    WidgetbookUseCase(
      name: 'Providers',
      builder: (c) => _group(
        _webProviders,
        header: c.l10n.toolsSetupHeader,
        footer: c.l10n.toolsSetupFooter,
      ),
    ),
    WidgetbookUseCase(name: 'Web, Advanced open', builder: (c) => _advanced(c)),
    WidgetbookUseCase(
      name: 'Web, Advanced closed',
      builder: (c) => _advanced(c, open: false),
    ),
    WidgetbookUseCase(
      name: 'Loading setup',
      builder: (c) => _section(c, ToolsLoadingRow(c.l10n.toolsSetupLoading)),
    ),
    WidgetbookUseCase(
      name: 'Couldn\'t load setup',
      builder: (c) => _section(
        c,
        ToolsFailureRow(text: c.l10n.toolsSetupLoadFailed, onRetry: () {}),
      ),
    ),
    WidgetbookUseCase(
      name: 'Nothing to set up',
      builder: (c) => _section(c, ToolsNothingRow(c.l10n.toolsSetupNothing)),
    ),
    WidgetbookUseCase(
      name: 'Loading setup, reduced motion',
      builder: (c) => Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: _section(c, ToolsLoadingRow(c.l10n.toolsSetupLoading)),
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Where commands run',
      builder: (c) => _group(
        _backends,
        header: c.l10n.toolsBackendsHeader,
        footer: c.l10n.toolsBackendsFooter,
      ),
    ),
    WidgetbookUseCase(
      name: 'Where commands run, loading',
      builder: (c) => _section(
        c,
        ToolsLoadingRow(c.l10n.toolsBackendsLoading),
        header: c.l10n.toolsBackendsHeader,
      ),
    ),
    WidgetbookUseCase(
      name: 'Where commands run, couldn\'t read',
      builder: (c) => _section(
        c,
        ToolsFailureRow(text: c.l10n.toolsBackendsLoadFailed, onRetry: () {}),
        header: c.l10n.toolsBackendsHeader,
      ),
    ),
    WidgetbookUseCase(
      name: 'Where commands run, largest text',
      builder: (c) => _at(
        3,
        () => _group(
          _backends,
          picked: 1,
          header: c.l10n.toolsBackendsHeader,
          footer: c.l10n.toolsBackendsFooter,
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Couldn\'t load, largest text',
      builder: (c) => _at(
        3,
        () => _section(
          c,
          ToolsFailureRow(text: c.l10n.toolsSetupLoadFailed, onRetry: () {}),
        ),
      ),
    ),
    ...onEachPlatform(
      'Where commands run',
      (c) => _group(
        _backends,
        picked: 1,
        header: c.l10n.toolsBackendsHeader,
        footer: c.l10n.toolsBackendsFooter,
      ),
    ),
  ],
);

/// A key form whose Replace works and whose Save plays a short save, so the
/// catalog can be played with. [phase] is where it starts.
class _KeyDemo extends StatefulWidget {
  const _KeyDemo({
    required this.fields,
    this.phase = ToolsetKeyFormPhase.idle,
    this.hideSignal = 0,
  });

  /// (label, typed text, is set, has link)
  final List<(String, String, bool, bool)> fields;
  final ToolsetKeyFormPhase phase;
  final int hideSignal;

  @override
  State<_KeyDemo> createState() => _KeyDemoState();
}

class _KeyDemoState extends State<_KeyDemo> {
  late List<TextEditingController> _controllers = _make();
  late List<bool> _replacing = [for (final _ in widget.fields) false];
  late var _phase = widget.phase;
  Timer? _timer;

  List<TextEditingController> _make() => [
    for (final field in widget.fields) TextEditingController(text: field.$2),
  ];

  @override
  void didUpdateWidget(_KeyDemo oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Moving to another use case reuses this state.
    _timer?.cancel();
    for (final controller in _controllers) {
      controller.dispose();
    }
    _controllers = _make();
    _replacing = [for (final _ in widget.fields) false];
    _phase = widget.phase;
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _save() {
    setState(() => _phase = ToolsetKeyFormPhase.saving);
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 1), () {
      if (!mounted) return;
      for (final controller in _controllers) {
        controller.clear();
      }
      setState(() {
        _phase = ToolsetKeyFormPhase.saved;
        _replacing = [for (final _ in widget.fields) false];
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final typed = _controllers.any((c) => c.text.trim().isNotEmpty);
    return Scaffold(
      body: GroupedListView(
        children: [
          ToolsetKeyForm(
            provider: 'Brightfetch',
            profile: 'work',
            hideSignal: widget.hideSignal,
            phase: _phase,
            fields: [
              for (final (i, field) in widget.fields.indexed)
                ToolsetKeyField(
                  label: field.$1,
                  controller: _controllers[i],
                  isSet: field.$3 && _phase != ToolsetKeyFormPhase.notSaved,
                  replacing: _replacing[i],
                  hasLink: field.$4,
                ),
            ],
            onChanged: () => setState(() {}),
            onSave: typed ? _save : null,
            onReplace: (field) => setState(() {
              final i = _controllers.indexOf(field.controller);
              _replacing[i] = true;
            }),
            onGetKey: (_) {},
          ),
        ],
      ),
    );
  }
}

const _oneKey = [('Brightfetch API key', '', false, true)];
const _typedKey = [
  ('Brightfetch API key', 'bf-live-0000-invented-key', false, true),
];
const _setKey = [('Brightfetch API key', '', true, true)];

WidgetbookNode _keyFormComponent() => WidgetbookComponent(
  name: 'ToolsetKeyForm',
  useCases: [
    WidgetbookUseCase(
      name: 'Empty',
      builder: (_) => const _KeyDemo(fields: _oneKey),
    ),
    WidgetbookUseCase(
      name: 'Typed',
      builder: (_) => const _KeyDemo(fields: _typedKey),
    ),
    WidgetbookUseCase(
      name: 'Saving',
      builder: (_) =>
          const _KeyDemo(fields: _typedKey, phase: ToolsetKeyFormPhase.saving),
    ),
    WidgetbookUseCase(
      name: 'Saved (Already set, Replace)',
      builder: (_) =>
          const _KeyDemo(fields: _setKey, phase: ToolsetKeyFormPhase.saved),
    ),
    WidgetbookUseCase(
      name: 'Already set, nothing saved just now',
      builder: (_) => const _KeyDemo(fields: _setKey),
    ),
    WidgetbookUseCase(
      name: 'Failed, typed value kept',
      builder: (_) => const _KeyDemo(
        fields: _typedKey,
        phase: ToolsetKeyFormPhase.failed,
        hideSignal: 1,
      ),
    ),
    WidgetbookUseCase(
      name: 'Answer lost, checking',
      builder: (_) =>
          const _KeyDemo(fields: _oneKey, phase: ToolsetKeyFormPhase.checking),
    ),
    WidgetbookUseCase(
      name: 'Couldn\'t confirm',
      builder: (_) => const _KeyDemo(
        fields: _setKey,
        phase: ToolsetKeyFormPhase.unconfirmed,
      ),
    ),
    WidgetbookUseCase(
      name: 'Key wasn\'t saved after the re-read',
      builder: (_) =>
          const _KeyDemo(fields: _oneKey, phase: ToolsetKeyFormPhase.notSaved),
    ),
    WidgetbookUseCase(
      name: 'Two keys, one set',
      builder: (_) => const _KeyDemo(
        fields: [
          ('Brightfetch API key', '', true, true),
          ('Brightfetch project id', 'proj-1234', false, false),
        ],
      ),
    ),
    WidgetbookUseCase(
      name: 'No link to a key page',
      builder: (_) =>
          const _KeyDemo(fields: [('Brightfetch API key', '', false, false)]),
    ),
    WidgetbookUseCase(
      name: 'Largest text, typed',
      builder: (_) => _at(3, () => const _KeyDemo(fields: _typedKey)),
    ),
    WidgetbookUseCase(
      name: 'Largest text, saved',
      builder: (_) => _at(
        3,
        () => const _KeyDemo(fields: _setKey, phase: ToolsetKeyFormPhase.saved),
      ),
    ),
    ...onEachPlatform('Typed', (_) => const _KeyDemo(fields: _typedKey)),
    ...onEachPlatform(
      'Saved',
      (_) => const _KeyDemo(fields: _setKey, phase: ToolsetKeyFormPhase.saved),
    ),
  ],
);

const _lines = [
  r'$ hermes tools post-setup brightdriver',
  'Resolving brightdriver 2.4.1',
  'Downloading brightdriver-2.4.1.tar.gz',
  'Unpacking (12 of 48 files)',
  'Unpacking (31 of 48 files)',
  'Unpacking (48 of 48 files)',
  'Linking the driver into the Hermes environment',
  'Checking the driver answers',
];

Widget _install(InstallPhase phase, {List<String> lines = _lines}) =>
    _page([InstallProgress(phase: phase, lines: lines, onTryAgain: () {})]);

Widget _button(
  BuildContext context, {
  required bool needsSetup,
  bool another = false,
}) => _page([
  Padding(
    padding: const EdgeInsets.only(top: 16),
    child: ToolsInstallButton(
      needsSetup: needsSetup,
      anotherRunning: another,
      onPressed: () {},
    ),
  ),
]);

WidgetbookNode _installComponent() => WidgetbookComponent(
  name: 'InstallProgress',
  useCases: [
    WidgetbookUseCase(
      name: 'Running, six lines of eight',
      builder: (_) => _install(InstallPhase.running),
    ),
    WidgetbookUseCase(
      name: 'Running, no lines yet',
      builder: (_) => _install(InstallPhase.running, lines: const []),
    ),
    WidgetbookUseCase(
      name: 'Started by a switch',
      builder: (_) => _install(InstallPhase.startedBySwitch),
    ),
    WidgetbookUseCase(
      name: 'Done',
      builder: (_) => _install(InstallPhase.done),
    ),
    WidgetbookUseCase(
      name: 'Failed',
      builder: (_) => _install(InstallPhase.failed),
    ),
    WidgetbookUseCase(
      name: 'Failed, long lines',
      builder: (_) => _install(
        InstallPhase.failed,
        lines: const [
          'error: could not resolve brightdriver==2.4.1 from the package index at the configured mirror',
          'error: the mirror answered 503 after 3 attempts',
        ],
      ),
    ),
    WidgetbookUseCase(
      name: 'Unknown',
      builder: (_) => _install(InstallPhase.unknown),
    ),
    WidgetbookUseCase(
      name: 'Running, reduced motion',
      builder: (_) => Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: _install(InstallPhase.running),
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Running, largest text',
      builder: (_) => _at(3, () => _install(InstallPhase.running)),
    ),
    WidgetbookUseCase(
      name: 'Failed, largest text',
      builder: (_) => _at(3, () => _install(InstallPhase.failed)),
    ),
    ...onEachPlatform('Running', (_) => _install(InstallPhase.running)),
    ...onEachPlatform('Failed', (_) => _install(InstallPhase.failed)),
    WidgetbookUseCase(
      name: 'Button, needs setup (filled)',
      builder: (c) => _button(c, needsSetup: true),
    ),
    WidgetbookUseCase(
      name: 'Button, run again (quiet)',
      builder: (c) => _button(c, needsSetup: false),
    ),
    WidgetbookUseCase(
      name: 'Button, another install is running',
      builder: (c) => _button(c, needsSetup: true, another: true),
    ),
    WidgetbookUseCase(
      name: 'Button, quiet, another install is running',
      builder: (c) => _button(c, needsSetup: false, another: true),
    ),
    WidgetbookUseCase(
      name: 'Button, largest text',
      builder: (c) => _at(3, () => _button(c, needsSetup: true)),
    ),
    ...onEachPlatform(
      'Button, needs setup',
      (c) => _button(c, needsSetup: true),
    ),
  ],
);

const _macMissingScreen = ComputerUseStatus(
  platform: 'darwin',
  platformSupported: true,
  installed: true,
  ready: false,
  canGrant: true,
  accessibility: true,
  screenRecording: false,
  checks: [
    ComputerUseCheck(label: 'Driver binary', status: 'ok', message: '2.4.1'),
    ComputerUseCheck(
      label: 'Screen recording',
      status: 'missing',
      message: 'Not granted to the driver.',
    ),
  ],
);

const _macNoDriver = ComputerUseStatus(
  platform: 'darwin',
  platformSupported: true,
  installed: false,
  canGrant: true,
);

const _linuxReady = ComputerUseStatus(
  platform: 'linux',
  platformSupported: true,
  installed: true,
  ready: true,
);

const _unknown = ComputerUseStatus(
  platform: 'linux',
  platformSupported: true,
  installed: true,
  error: 'The driver did not answer within 5 seconds.',
);

Widget _readiness(
  BuildContext context,
  ComputerUseStatus status, {
  bool screen = false,
  bool open = false,
  bool install = false,
  bool grant = false,
}) {
  final l10n = context.l10n;
  return _page([
    ReadinessSection(
      items: readinessItems(l10n, status),
      details: [
        for (final check in status.checks)
          ReadinessDetail(label: check.label, text: check.message),
      ],
      errorText: status.error,
      detailsInitiallyOpen: open,
      onOpenBotScreen: screen ? () {} : null,
      onInstall: install ? () {} : null,
      onAllowAccess: grant ? () {} : null,
    ),
  ]);
}

WidgetbookNode _readinessComponent() => WidgetbookComponent(
  name: 'ReadinessSection',
  useCases: [
    WidgetbookUseCase(
      name: 'Mac server, screen recording missing',
      builder: (c) => _readiness(c, _macMissingScreen, grant: true),
    ),
    WidgetbookUseCase(
      name: 'Mac server, driver missing',
      builder: (c) => _readiness(c, _macNoDriver, install: true),
    ),
    WidgetbookUseCase(
      name: 'Linux server, ready',
      builder: (c) => _readiness(c, _linuxReady),
    ),
    WidgetbookUseCase(
      name: 'Unknown readiness, Hermes\' error',
      builder: (c) => _readiness(c, _unknown),
    ),
    WidgetbookUseCase(
      name: 'Details open',
      builder: (c) => _readiness(c, _macMissingScreen, open: true),
    ),
    WidgetbookUseCase(
      name: 'With the bot\'s screen row',
      builder: (c) => _readiness(c, _linuxReady, screen: true),
    ),
    WidgetbookUseCase(
      name: 'Everything allowed on a Mac server',
      builder: (c) => _readiness(
        c,
        const ComputerUseStatus(
          platform: 'darwin',
          platformSupported: true,
          installed: true,
          ready: true,
          canGrant: true,
          accessibility: true,
          screenRecording: true,
        ),
        screen: true,
      ),
    ),
    WidgetbookUseCase(
      name: 'Largest text',
      builder: (c) =>
          _at(3, () => _readiness(c, _macMissingScreen, grant: true)),
    ),
    WidgetbookUseCase(
      name: 'Twice the text, unknown',
      builder: (c) => _at(2, () => _readiness(c, _unknown)),
    ),
    ...onEachPlatform(
      'Mac server, screen recording missing',
      (c) => _readiness(c, _macMissingScreen, grant: true, screen: true),
    ),
  ],
);

const _models = [
  ToolsetModel(
    id: 'bright-fast',
    display: 'Bright Fast',
    speed: 'Quick, about 3 seconds',
    strengths: 'Good for drafts',
    price: '\$0.01 per image',
  ),
  ToolsetModel(
    id: 'bright-pro',
    display: 'Bright Pro',
    speed: 'About 12 seconds',
    strengths: 'Detailed pictures with readable text',
    price: '\$0.05 per image, more at 4K',
  ),
  ToolsetModel(id: 'bright-sketch', display: 'Bright Sketch'),
  ToolsetModel(
    id: 'bright-video',
    display: 'Bright Motion with a long name that wraps',
    speed: 'Minutes, not seconds',
    strengths: 'Five second clips; the price depends on length and size',
    price: 'From \$0.40 per clip',
  ),
];

Widget _sheetBox(Widget child) => Align(
  alignment: Alignment.bottomCenter,
  child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 440),
    child: Builder(
      builder: (context) => Material(
        color: Theme.of(context).colorScheme.surface,
        elevation: 6,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    ),
  ),
);

class _SheetDemo extends StatefulWidget {
  const _SheetDemo({this.current = 'bright-pro'});

  final String current;

  @override
  State<_SheetDemo> createState() => _SheetDemoState();
}

class _SheetDemoState extends State<_SheetDemo> {
  late String _current = widget.current;

  @override
  void didUpdateWidget(_SheetDemo oldWidget) {
    super.didUpdateWidget(oldWidget);
    _current = widget.current;
  }

  @override
  Widget build(BuildContext context) => _sheetBox(
    ToolsetModelSheet(
      models: _models,
      current: _current,
      defaultModel: 'bright-fast',
      provider: 'Brightfetch',
      onPick: (id) => setState(() => _current = id),
      onDone: () {},
    ),
  );
}

WidgetbookNode _modelComponent() => WidgetbookComponent(
  name: 'ToolsetModelSheet',
  useCases: [
    WidgetbookUseCase(name: 'Models', builder: (_) => const _SheetDemo()),
    WidgetbookUseCase(
      name: 'The default is picked',
      builder: (_) => const _SheetDemo(current: 'bright-fast'),
    ),
    WidgetbookUseCase(
      name: 'Largest text',
      builder: (_) => _at(3, () => const _SheetDemo()),
    ),
    WidgetbookUseCase(
      name: 'Twice the text',
      builder: (_) => _at(2, () => const _SheetDemo()),
    ),
    ...onEachPlatform('Models', (_) => const _SheetDemo()),
    WidgetbookUseCase(
      name: 'Opened from a row',
      builder: (c) => Scaffold(
        body: GroupedListView(
          children: [
            GroupedSection(
              children: [
                GroupedRow(
                  title: c.l10n.toolsModelTitle,
                  value: 'Bright Pro',
                  onTap: () => showToolsetModelSheet(
                    c,
                    models: _models,
                    current: 'bright-pro',
                    defaultModel: 'bright-fast',
                    provider: 'Brightfetch',
                    onPick: (_) {},
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  ],
);

Widget _backdrop(Widget dialog) => Builder(
  builder: (context) => ColoredBox(
    color: Colors.black.withValues(alpha: 0.4),
    child: Center(child: dialog),
  ),
);

WidgetbookNode _confirmComponent() {
  ToolsetQuestion Function(AppLocalizations) of(String name) =>
      (l10n) => toolsetConfirmQuestion(l10n, name, 'work')!;
  final questions = <(String, ToolsetQuestion Function(AppLocalizations))>[
    ('Terminal', of('terminal')),
    ('Browser', of('browser')),
    ('Code execution', of('code_execution')),
    ('Computer use', of('computer_use')),
    (
      'Another tool with an install step',
      (l10n) => toolsetInstallQuestion(l10n, 'Image generation'),
    ),
    ('Local backend', toolsetLocalBackendQuestion),
    ('Install', toolsetInstallStepQuestion),
    ('Allow access', toolsetAllowAccessQuestion),
  ];
  return WidgetbookComponent(
    name: 'Confirmations',
    useCases: [
      for (final (name, question) in questions)
        ...onEachPlatform(
          name,
          (c) => _backdrop(ToolsetConfirmDialog(question: question(c.l10n))),
        ),
      WidgetbookUseCase(
        name: 'Opened by showToolsetConfirmation',
        builder: (_) => openOnShow(
          (context) => showToolsetConfirmation(
            context,
            toolsetConfirmQuestion(context.l10n, 'terminal', 'work')!,
          ).then((_) {}),
        ),
      ),
      WidgetbookUseCase(
        name: 'Twice the text (Computer use)',
        builder: (c) => _at(
          2,
          () => _backdrop(
            ToolsetConfirmDialog(question: of('computer_use')(c.l10n)),
          ),
        ),
      ),
    ],
  );
}

class _DifferenceDemo extends StatelessWidget {
  const _DifferenceDemo();

  @override
  Widget build(BuildContext context) =>
      _sheetBox(ToolsDifferenceSheet(onDone: () {}));
}

WidgetbookNode _differenceComponent() => WidgetbookComponent(
  name: 'ToolsDifferenceSheet',
  useCases: [
    WidgetbookUseCase(name: 'Sheet', builder: (_) => const _DifferenceDemo()),
    WidgetbookUseCase(
      name: 'Largest text',
      builder: (_) => _at(3, () => const _DifferenceDemo()),
    ),
    ...onEachPlatform('Sheet', (_) => const _DifferenceDemo()),
    WidgetbookUseCase(
      name: 'Opened from a link',
      builder: (_) =>
          openOnShow((context) => showToolsDifferenceSheet(context)),
    ),
  ],
);

/// The Tools setup components: provider rows and their states, the key form,
/// install, readiness, the model sheet, the confirmations and "What's the
/// difference?".
List<WidgetbookNode> toolsSetupComponents() => [
  _providerRowComponent(),
  _setupComponent(),
  _keyFormComponent(),
  _installComponent(),
  _readinessComponent(),
  _modelComponent(),
  _confirmComponent(),
  _differenceComponent(),
];
