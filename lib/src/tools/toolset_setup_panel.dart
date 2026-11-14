import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../providers/provider_flow.dart' show SecretFieldsLock;
import '../widgets/adaptive_sheet.dart';
import '../widgets/grouped_list.dart';
import 'toolset_copy.dart';
import 'toolset_installs.dart';
import 'toolset_setup_controller.dart';
import 'tools_models.dart';
import 'tools_panel_env.dart';
import 'tools_write.dart';
import 'widgets/install_progress.dart';
import 'widgets/provider_choice_section.dart';
import 'widgets/status_chip.dart';
import 'widgets/tools_disclosure.dart';
import 'widgets/tools_load_state.dart';
import 'widgets/tools_note.dart';
import 'widgets/toolset_key_form.dart';
import 'widgets/toolset_model_row.dart';
import 'widgets/toolset_model_sheet.dart';

/// The setup area of one open toolset's details: where the toolset gets what
/// it needs from (the providers), the keys of the one picked, the install
/// step, and the model of image and video generation.
///
/// It shows the [ToolsetSetupController] the screen's registry keeps (so a
/// write goes on, and its result is waiting, when the panel is gone) and owns
/// the one [TextEditingController] per key the form shows, and nothing else:
/// typed keys live in those fields and in the controller's private map, are
/// cleared by a successful save, a lost answer, App Lock, a provider or
/// profile change and when the panel goes away, and are never read back out
/// or logged. The install runs on the connection's `ToolsetInstalls`, which
/// outlives the panel.
class ToolsetSetupPanel extends StatefulWidget {
  const ToolsetSetupPanel({
    super.key,
    required this.toolset,
    required this.env,
  });

  final Toolset toolset;
  final ToolsPanelEnv env;

  @override
  State<ToolsetSetupPanel> createState() => _ToolsetSetupPanelState();
}

class _ToolsetSetupPanelState extends State<ToolsetSetupPanel> {
  late ToolsetSetupController _setup;
  final _fields = <String, TextEditingController>{};
  final _replacing = <String>{};
  late bool _expanded;
  var _advanced = false;
  var _hideSignal = 0;
  var _prevKeys = ToolsetKeysState.idle;
  var _rereading = false;
  ToolsInstallState? _handledEnd;
  String? _modelsFor;
  late final ToolsetInstalls _installs = widget.env.installs;
  SecretFieldsLock? _lockWatch;

  String get _name => widget.toolset.name;
  String get _ownerKey => 'setup:$_name';

  @override
  void initState() {
    super.initState();
    // Open when the toolset needs setup, and it stays open when what the
    // user does there sets it up.
    _setup = widget.env.registry.setup(_name)..addListener(_onSetup);
    // The layout may have built this panel before the one it replaces is
    // disposed: from here on this one owns what the controller shows.
    widget.env.registry.claim(_ownerKey, this);
    _prevKeys = _setup.keysState;
    // A result that waited for the user (a save that ended while another
    // toolset was open) shows open.
    _expanded =
        !widget.toolset.configured ||
        _setup.keysState != ToolsetKeysState.idle ||
        _setup.providerState != ToolsWriteState.idle ||
        _setup.modelState != ToolsWriteState.idle ||
        _setup.hasTypedKeys;
    _lockWatch = SecretFieldsLock(widget.env.lock, () => _setup.clearKeys());
    // After this frame: the read tells every panel that shows the controller
    // (the one this replaces may still be mounted), and a panel cannot be
    // rebuilt while another builds.
    scheduleMicrotask(() {
      if (mounted) unawaited(_setup.load());
    });
    widget.env.refresh.add(_refresh);
    widget.env.refresh.addClear(_clearTyped);
    _installs.addListener(_onInstalls);
    // An install that ended with no screen open shows its result now.
    WidgetsBinding.instance.addPostFrameCallback((_) => _onInstalls());
  }

  @override
  void dispose() {
    widget.env.refresh.remove(_refresh);
    widget.env.refresh.removeClear(_clearTyped);
    _installs.removeListener(_onInstalls);
    _lockWatch?.dispose();
    _closeModelSheet();
    final state = _installs.state;
    // A panel that another one replaced does not own the controller any
    // more: what it shows now belongs to the new panel.
    final owner = widget.env.registry.release(_ownerKey, this);
    final showed =
        owner && _handledEnd != null && identical(state, _handledEnd);
    // The controller stays with the screen: a write goes on and its result
    // waits here. What was typed goes.
    _setup.removeListener(_onSetup);
    if (owner) {
      _setup.clearKeys(notify: false);
      // Seen: a later visit starts clean. A write still running keeps its
      // result for the user's return.
      if (!_writing) _setup.acknowledge();
    }
    for (final field in _fields.values) {
      field
        ..clear()
        ..dispose();
    }
    _fields.clear();
    // After the frame: both notify listeners that are being torn down too.
    scheduleMicrotask(() {
      if (showed && state?.phase == ToolsInstallPhase.succeeded) {
        _installs.acknowledge();
      }
    });
    super.dispose();
  }

  Future<void> _refresh() => _setup.refresh();

  void _clearTyped() => _setup.clearKeys();

  /// A write of this toolset's setup is out. Read from the states, not from
  /// the controller's `writing`, which is still true when the write's last
  /// notification arrives.
  bool get _writing {
    bool busy(ToolsWriteState state) =>
        state == ToolsWriteState.saving || state == ToolsWriteState.checking;
    return busy(_setup.providerState) ||
        busy(_setup.modelState) ||
        _setup.keysState == ToolsetKeysState.saving ||
        _setup.keysState == ToolsetKeysState.checking;
  }

  /// Nothing may be picked, saved or installed: a setup write is out, or the
  /// toolset's own switch is being written.
  bool get _locked => _writing || widget.env.locked;

  /// A field starts with what the controller holds for it, which is only
  /// something when this panel replaced one that had it typed.
  TextEditingController _field(String key) => _fields.putIfAbsent(
    key,
    () => TextEditingController(text: _setup.typedValue(key)),
  );

  void _onSetup() {
    if (!mounted) return;
    // The controller is the authority on what is typed: when it dropped the
    // values (a successful save, a lost answer, a provider change, App Lock)
    // the fields follow.
    for (final entry in _fields.entries) {
      if (_setup.typedLength(entry.key) == 0 && entry.value.text.isNotEmpty) {
        entry.value.clear();
      }
    }
    final keys = _setup.keysState;
    if (keys == ToolsetKeysState.failed && _prevKeys != keys) _hideSignal++;
    if (keys == ToolsetKeysState.saved) _replacing.clear();
    _prevKeys = keys;
    _maybeLoadModels();
    setState(() {});
  }

  void _maybeLoadModels() {
    final config = _setup.config;
    if (!kModelToolsets.contains(_name) || config == null) return;
    final active = config.activeProvider ?? '';
    if (_modelsFor == active) return;
    _modelsFor = active;
    unawaited(_setup.loadModels());
  }

  void _onInstalls() {
    if (!mounted) return;
    final state = _installs.state;
    if (state != null &&
        state.toolset == _name &&
        !state.active &&
        !identical(state, _handledEnd)) {
      _handledEnd = state;
      unawaited(_afterInstall(state));
    }
    setState(() {});
  }

  /// The install ended: reads what the toolset needs again, and the list, and
  /// only then says "Installed." The result is never taken from the log.
  Future<void> _afterInstall(ToolsInstallState state) async {
    final succeeded = state.phase == ToolsInstallPhase.succeeded;
    if (succeeded) setState(() => _rereading = true);
    await _setup.load();
    if (!mounted) return;
    widget.env.onWritten();
    if (succeeded) setState(() => _rereading = false);
  }

  Future<void> _install(String key) async {
    if (_installs.busy || _locked) return;
    final repository = widget.env.repository;
    final confirmed = await widget.env.ask(
      toolsetInstallStepQuestion(context.l10n),
    );
    if (!confirmed || !mounted) return;
    // The answer was for the profile the question was asked about.
    if (widget.env.repository.profile != repository.profile) return;
    // A write may have started while the question was open (a key save, a
    // switch, a pick or an install from elsewhere): nothing runs on top.
    if (_installs.busy || _locked) return;
    await _installs.startConfirmed(repository, _name, key);
  }

  Future<void> _openLink(String? url) async {
    final uri = toolsWebLink(url);
    if (uri == null) return;
    try {
      await widget.env.launchLink(uri);
    } on Object {
      // Nothing to say: the user can still copy the page from Hermes.
      return;
    }
  }

  Future<void> _openModels(String provider) async {
    final catalog = _setup.models;
    if (catalog == null || !catalog.hasModels) return;
    final profile = widget.env.repository.profile;
    await showAdaptiveSheet<void>(
      context,
      maxWidth: 440,
      builder: (sheet) {
        _sheetRoute = ModalRoute.of(sheet);
        _sheetNavigator = Navigator.of(sheet);
        return ListenableBuilder(
          listenable: _setup,
          builder: (_, _) {
            final models = _setup.models ?? catalog;
            return SafeArea(
              child: ToolsetModelSheet(
                models: models.models,
                current: models.current,
                defaultModel: models.defaultModel,
                provider: provider,
                onPick: (id) {
                  // A late tap sends nothing: the panel went, the profile
                  // changed, or the switch is being written.
                  if (!mounted ||
                      widget.env.repository.profile != profile ||
                      _locked) {
                    return;
                  }
                  unawaited(_setup.pickModel(id));
                },
                onDone: () => Navigator.of(sheet).pop(),
              ),
            );
          },
        );
      },
    );
    _sheetRoute = null;
    _sheetNavigator = null;
  }

  Route<dynamic>? _sheetRoute;
  NavigatorState? _sheetNavigator;

  /// Takes the model list down with the panel (a profile change closes the
  /// details page under it).
  void _closeModelSheet() {
    final route = _sheetRoute;
    final navigator = _sheetNavigator;
    _sheetRoute = null;
    _sheetNavigator = null;
    if (route == null || navigator == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigator.mounted && route.isActive) navigator.removeRoute(route);
    });
  }

  // ---- building ----

  ToolsetProvider? _selected(ToolsetConfig config) {
    final name = _setup.selectedProvider;
    return config.providers.where((p) => p.name == name).firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final desktop = toolsOnDesktop(context);
    final config = _setup.config;
    final install = _installBlock(context);
    final Widget setup;
    if (config == null) {
      setup = GroupedSection(
        header: l10n.toolsSetupHeader,
        children: [
          if (_setup.loadFailure != null)
            ToolsFailureRow(
              text: l10n.toolsSetupLoadFailed,
              onRetry: () => unawaited(_setup.load()),
            )
          else
            ToolsLoadingRow(l10n.toolsSetupLoading),
        ],
      );
    } else if (!config.hasCategory || config.providers.isEmpty) {
      // Terminal has its own "Where commands run"; "Nothing to set up" above
      // it would only confuse.
      setup = _name == 'terminal' && widget.toolset.configured
          ? const SizedBox.shrink()
          : GroupedSection(
              header: l10n.toolsSetupHeader,
              children: [ToolsNothingRow(l10n.toolsSetupNothing)],
            );
    } else {
      final content = _content(context, config, desktop: desktop);
      final active = config.providers
          .where((p) => p.name == config.activeProvider)
          .firstOrNull;
      setup = widget.toolset.configured
          ? ToolsDisclosure(
              title: l10n.toolsSetupChange,
              value: active?.name,
              expanded: _expanded,
              onExpandedChanged: (open) => setState(() => _expanded = open),
              children: content,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: content,
            );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [?install, setup, ..._modelSection(context, config, desktop)],
    );
  }

  List<Widget> _content(
    BuildContext context,
    ToolsetConfig config, {
    required bool desktop,
  }) {
    final l10n = context.l10n;
    final selected = _selected(config);
    final writing = _locked;
    ProviderChoice choice(
      ToolsetProvider p, {
      required bool picked,
      bool nous = false,
    }) => ProviderChoice(
      id: p.name,
      name: p.name,
      status: _status(p),
      picked: picked,
      badge: p.badge,
      line: p.tag,
      needsNousSignIn:
          nous ||
          (p.requiresNousAuth && p.status == ToolsetProviderStatus.needsAuth),
    );
    final nousFlag = _setup.needsNousAuth;
    final choices = [
      for (final p in config.providers)
        choice(
          p,
          picked: p.name == _setup.selectedProvider,
          nous: nousFlag && p.name == _setup.selectedProvider,
        ),
    ];
    final out = <Widget>[
      ProviderChoiceSection(
        header: l10n.toolsSetupHeader,
        footer: l10n.toolsSetupFooter,
        choices: choices,
        enabled: !writing,
        // The selection moves only when Hermes accepted the pick, so a
        // refusal leaves the old provider and its keys on screen.
        onPick: (id) {
          if (!_locked) unawaited(_setup.pickProvider(id));
        },
      ),
      ?_writeNote(
        context,
        state: _setup.providerState,
        refusal: _setup.providerRefusalDetail,
        failed: l10n.toolsWriteFailedSetup,
        desktop: desktop,
      ),
    ];

    final needsNous =
        selected != null &&
        (nousFlag ||
            (selected.requiresNousAuth &&
                selected.status == ToolsetProviderStatus.needsAuth));
    var editableKeys = false;
    if (selected != null && selected.envVars.isNotEmpty && !needsNous) {
      final envs = selected.envVars;
      final fields = [
        for (final env in envs)
          ToolsetKeyField(
            label: env.prompt,
            controller: _field(env.key),
            isSet: env.isSet,
            replacing:
                _replacing.contains(env.key) || _setup.typedLength(env.key) > 0,
            hasLink: toolsWebLink(env.url) != null,
          ),
      ];
      editableKeys = fields.any((f) => f.editable);
      out.add(
        ToolsetKeyForm(
          provider: selected.name,
          profile: widget.env.repository.profile,
          fields: fields,
          phase: ToolsetKeyFormPhase.values.byName(_setup.keysState.name),
          hideSignal: _hideSignal,
          onChanged: () {
            for (final env in envs) {
              _setup.setKey(env.key, _field(env.key).text);
            }
          },
          onSave: _setup.hasTypedKeys && !widget.env.locked
              ? () => unawaited(_setup.saveKeys())
              : null,
          onReplace: (field) => setState(() {
            final i = fields.indexOf(field);
            if (i >= 0) _replacing.add(envs[i].key);
          }),
          onGetKey: (field) {
            final i = fields.indexOf(field);
            if (i >= 0) unawaited(_openLink(envs[i].url));
          },
          onTryAgain: desktop ? () => unawaited(_setup.refresh()) : null,
        ),
      );
      final refusal = _setup.refusalDetail;
      if (_setup.keysState == ToolsetKeysState.failed &&
          (refusal?.trim().isNotEmpty ?? false)) {
        out.add(ToolsNote(tone: ToolsNoteTone.error, text: refusal!));
      }
    }

    final step = selected?.postSetup;
    // This toolset's install shows its own block (running, failed with its
    // Try again, checking, unknown); the setup area's button is only for when
    // there is none, so two buttons never do the same thing.
    final installState = _installs.state;
    final mine = installState?.toolset == _name;
    final active =
        mine &&
        installState != null &&
        installState.phase != ToolsInstallPhase.refused &&
        installState.phase != ToolsInstallPhase.notStarted;
    final fillInstall =
        selected?.status == ToolsetProviderStatus.needsSetup && !editableKeys;
    if (step != null && fillInstall && !active) {
      out.add(
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: ToolsInstallButton(
            needsSetup: true,
            anotherRunning: _installs.busy,
            onPressed: _locked ? null : () => unawaited(_install(step)),
          ),
        ),
      );
    }
    final installNote = _installNote(context);
    if (installNote != null) out.add(installNote);

    final advanced = _advancedContent(
      context,
      config,
      selected,
      // With a key still to type the step waits: it is offered once the key
      // is saved.
      showInstallAgain:
          step != null && !fillInstall && !active && !editableKeys,
      installRan: selected?.status == ToolsetProviderStatus.ready,
    );
    if (advanced.isNotEmpty) {
      out.add(
        ToolsDisclosure(
          title: _name == 'web' && config.providers.any(_splits)
              ? l10n.toolsSetupAdvancedTitle
              : l10n.toolsSetupAdvancedGeneric,
          expanded: _advanced,
          onExpandedChanged: (open) => setState(() => _advanced = open),
          children: advanced,
        ),
      );
    }
    return out;
  }

  /// A provider with an install step that has not run reads "Needs install";
  /// any other status the app does not know reads "Needs setup".
  ToolsStatus _status(ToolsetProvider p) =>
      p.status == ToolsetProviderStatus.needsSetup && p.postSetup != null
      ? ToolsStatus.needsInstall
      : ToolsStatus.fromProvider(p.status);

  bool _splits(ToolsetProvider p) =>
      p.webBackend != null && p.capabilities.isNotEmpty;

  List<Widget> _advancedContent(
    BuildContext context,
    ToolsetConfig config,
    ToolsetProvider? selected, {
    required bool showInstallAgain,
    required bool installRan,
  }) {
    final l10n = context.l10n;
    final writing = _locked;
    final out = <Widget>[];
    if (_name == 'web') {
      ProviderChoiceSection pickers(
        String capability,
        String header,
        String? active, {
        String? footer,
      }) => ProviderChoiceSection(
        header: header,
        footer: footer,
        enabled: !writing,
        choices: [
          for (final p in config.providers)
            if (_splits(p) && p.capabilities.contains(capability))
              ProviderChoice(
                id: p.name,
                name: p.name,
                status: _status(p),
                picked: p.webBackend == active,
                badge: p.badge,
                line: p.tag,
              ),
        ],
        onPick: (id) {
          if (!_locked) {
            unawaited(_setup.pickProvider(id, capability: capability));
          }
        },
      );
      if (config.providers.any(_splits)) {
        out
          ..add(
            pickers(
              'search',
              l10n.toolsSetupSearchHeader,
              config.activeSearchBackend,
            ),
          )
          ..add(
            pickers(
              'extract',
              l10n.toolsSetupExtractHeader,
              config.activeExtractBackend,
              footer: l10n.toolsSetupAdvancedFooter,
            ),
          );
      }
    }
    final step = selected?.postSetup;
    if (showInstallAgain && step != null) {
      out.add(
        GroupedSection(
          header: l10n.toolsInstallHeader,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ToolsInstallButton(
                needsSetup: false,
                again: installRan,
                anotherRunning: _installs.busy,
                onPressed: _locked ? null : () => unawaited(_install(step)),
              ),
            ),
          ],
        ),
      );
    }
    return out;
  }

  /// A line about the last write of a section: what is out, what failed.
  Widget? _writeNote(
    BuildContext context, {
    required ToolsWriteState state,
    required String? refusal,
    required String failed,
    required bool desktop,
  }) {
    final l10n = context.l10n;
    switch (state) {
      case ToolsWriteState.idle:
        return null;
      case ToolsWriteState.saving:
        return ToolsLoadingRow(l10n.toolsWriteSaving);
      case ToolsWriteState.checking:
        return ToolsLoadingRow(l10n.toolsRowChecking);
      case ToolsWriteState.unconfirmed:
        return ToolsNote(
          tone: ToolsNoteTone.warning,
          text: desktop
              ? l10n.toolsRowUnconfirmedRetry
              : l10n.toolsRowUnconfirmedPull,
          actionLabel: desktop ? l10n.toolsTryAgain : null,
          onAction: desktop ? () => unawaited(_setup.refresh()) : null,
        );
      case ToolsWriteState.notApplied:
        return ToolsNote(
          tone: ToolsNoteTone.warning,
          text: l10n.toolsWriteNotApplied,
        );
      case ToolsWriteState.refused:
        return ToolsNote(
          tone: ToolsNoteTone.error,
          text: (refusal?.trim().isNotEmpty ?? false) ? refusal! : failed,
        );
      case ToolsWriteState.failed:
        return ToolsNote(tone: ToolsNoteTone.error, text: failed);
    }
  }

  List<Widget> _modelSection(
    BuildContext context,
    ToolsetConfig? config,
    bool desktop,
  ) {
    final l10n = context.l10n;
    if (!kModelToolsets.contains(_name) ||
        config == null ||
        config.activeProvider == null) {
      return const [];
    }
    final catalog = _setup.models;
    final provider = catalog?.provider ?? config.activeProvider ?? '';
    if (catalog == null) {
      if (_setup.modelsLoading) {
        return [
          const ToolsetModelRow(
            phase: ToolsetModelRowPhase.loading,
            provider: '',
          ),
        ];
      }
      if (_setup.modelsFailure != null) {
        return [
          ToolsetModelRow(
            phase: ToolsetModelRowPhase.failed,
            provider: provider,
            onRetry: () => unawaited(_setup.loadModels()),
          ),
        ];
      }
      return const [];
    }
    if (!catalog.hasModels) return const [];
    final current = catalog.models
        .where((m) => m.id == catalog.current)
        .firstOrNull;
    final defaultModel = catalog.models
        .where((m) => m.id == catalog.defaultModel)
        .firstOrNull;
    return [
      ToolsetModelRow(
        phase: ToolsetModelRowPhase.ready,
        provider: provider,
        value: (current ?? defaultModel)?.display ?? l10n.toolsModelDefault,
        enabled: !_locked,
        onOpen: () => unawaited(_openModels(provider)),
      ),
      ?_writeNote(
        context,
        state: _setup.modelState,
        refusal: _setup.modelRefusalDetail,
        failed: l10n.toolsWriteFailedModel,
        desktop: desktop,
      ),
    ];
  }

  // ---- install ----

  /// The install this toolset's section shows: running, ended or lost.
  Widget? _installBlock(BuildContext context) {
    final l10n = context.l10n;
    final state = _installs.state;
    if (state == null || state.toolset != _name) return null;
    final key = state.key;
    final lines = state.lines;
    Widget? followNote() {
      if (state.followLost) {
        return ToolsNote(
          tone: ToolsNoteTone.warning,
          text: l10n.toolsInstallFollowLost,
          actionLabel: l10n.toolsCheckAgain,
          onAction: _installs.checkAgain,
        );
      }
      if (state.followFailing) {
        return ToolsNote(
          tone: ToolsNoteTone.warning,
          text: l10n.toolsInstallFollowRetrying,
        );
      }
      return null;
    }

    switch (state.phase) {
      case ToolsInstallPhase.starting:
      case ToolsInstallPhase.running:
        return InstallProgress(
          phase: state.switchStarted
              ? InstallPhase.startedBySwitch
              : InstallPhase.running,
          lines: lines,
          runningTitle: state.startLost
              ? l10n.toolsInstallMayHaveStarted
              : null,
          extra: followNote(),
        );
      case ToolsInstallPhase.succeeded:
        return InstallProgress(
          phase: _rereading ? InstallPhase.checking : InstallPhase.done,
          lines: lines,
        );
      case ToolsInstallPhase.failed:
        return InstallProgress(
          phase: InstallPhase.failed,
          lines: lines,
          onTryAgain: key == null || _installs.busy || _locked
              ? null
              : () => unawaited(_install(key)),
        );
      case ToolsInstallPhase.unknown:
        return InstallProgress(
          phase: InstallPhase.unknown,
          lines: lines,
          extra: followNote(),
        );
      case ToolsInstallPhase.refused:
      case ToolsInstallPhase.notStarted:
        return null;
    }
  }

  /// Why an install did not start: Hermes' own text, or a plain sentence.
  Widget? _installNote(BuildContext context) {
    final state = _installs.state;
    if (state == null || state.toolset != _name) return null;
    final l10n = context.l10n;
    return switch (state.phase) {
      ToolsInstallPhase.refused => ToolsNote(
        tone: ToolsNoteTone.error,
        text: (state.detail?.trim().isNotEmpty ?? false)
            ? state.detail!
            : l10n.toolsInstallNotStarted,
      ),
      ToolsInstallPhase.notStarted => ToolsNote(
        tone: ToolsNoteTone.error,
        text: l10n.toolsInstallNotStarted,
      ),
      _ => null,
    };
  }
}
