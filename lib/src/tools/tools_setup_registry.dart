import 'package:flutter/foundation.dart';

import 'computer_use_controller.dart';
import 'hermes_tools_repository.dart';
import 'terminal_backends_controller.dart';
import 'toolset_setup_controller.dart';
import 'tools_write.dart';

/// The controllers of the open Tools screen's setup, which outlive the
/// details panels that show them. There is one per toolset the user opened
/// (so the list bounds it) and they are freed when the screen goes ([dispose]).
///
/// A write belongs to its controller, not to the panel that started it: when
/// the user opens another toolset mid-save the panel goes, the write runs on,
/// and the toolset's switch stays locked until the write settles. Coming back
/// shows the controller's state (saved, failed, "May have saved. Checking…"),
/// so a result is never lost with a panel. Typed keys are the exception: they
/// go with the panel ([ToolsetSetupController.clearKeys]), with App Lock, a
/// profile change and sign-out ([clearKeys]), and the controllers go with the
/// screen ([dispose]).
///
/// The lock is reported through [onBusyChanged] when a controller starts or
/// ends a write; a landed write calls [onWritten] so the list is read again.
class ToolsSetupRegistry {
  ToolsSetupRegistry({
    required this.repository,
    required this.confirmLocal,
    required this.confirmGrant,
    required this.onWritten,
    required this.onBusyChanged,
  });

  /// The profile's repository; moves with [switchProfile].
  HermesToolsRepository repository;
  final Future<bool> Function() confirmLocal;
  final Future<bool> Function() confirmGrant;
  final VoidCallback onWritten;
  final void Function(String toolset, {required bool busy}) onBusyChanged;

  final _setups = <String, ToolsetSetupController>{};
  TerminalBackendsController? _backends;
  ComputerUseController? _computer;
  final _busy = <String, bool>{};
  var _backendWriting = false;
  var _disposed = false;

  /// The panel that shows each controller now, by key. A panel the layout
  /// rebuilds (the pane becoming a page, a details page opened again during
  /// the pop animation) is built before the old one is disposed, so the old
  /// one must not drop what the new one shows: only the owner at dispose
  /// time acknowledges a result, drops typed keys or the shown install.
  final _owners = <String, Object>{};

  /// Makes [panel] the owner of [key]'s controller: the panel's initState.
  void claim(String key, Object panel) => _owners[key] = panel;

  /// Gives [key] up: the panel's dispose. True when [panel] was the owner and
  /// may therefore clean up; false when another panel took over meanwhile.
  bool release(String key, Object panel) {
    if (!identical(_owners[key], panel)) return false;
    _owners.remove(key);
    return true;
  }

  ToolsetSetupController setup(String toolset) =>
      _setups.putIfAbsent(toolset, () {
        final controller = ToolsetSetupController(
          repository,
          toolset: toolset,
          telemetry: repository.telemetry,
          onWritten: onWritten,
        );
        controller.addListener(() {
          _report('setup:$toolset', toolset, _setupWriting(controller));
        });
        return controller;
      });

  TerminalBackendsController get backends =>
      _backends ??= TerminalBackendsController(
        repository,
        telemetry: repository.telemetry,
        confirmLocal: confirmLocal,
      )..addListener(_onBackends);

  ComputerUseController get computer => _computer ??=
      ComputerUseController(
        repository,
        telemetry: repository.telemetry,
        confirmGrant: confirmGrant,
      )..addListener(
        () => _report('computer', 'computer_use', _computer!.grantBusy),
      );

  static bool _setupWriting(ToolsetSetupController c) {
    bool busy(ToolsWriteState s) =>
        s == ToolsWriteState.saving || s == ToolsWriteState.checking;
    return busy(c.providerState) ||
        busy(c.modelState) ||
        c.keysState == ToolsetKeysState.saving ||
        c.keysState == ToolsetKeysState.checking;
  }

  void _onBackends() {
    final c = _backends!;
    final writing =
        c.pickState == ToolsWriteState.saving ||
        c.pickState == ToolsWriteState.checking;
    _report('backends', 'terminal', writing);
    if (_backendWriting && !writing && c.pickState == ToolsWriteState.idle) {
      onWritten();
    }
    _backendWriting = writing;
  }

  void _report(String key, String toolset, bool busy) {
    if (_disposed || (_busy[key] ?? false) == busy) return;
    _busy[key] = busy;
    onBusyChanged(toolset, busy: busy);
  }

  /// Hands every controller to another profile: answers on their way are
  /// dropped, typed keys go, and every lock is released.
  void switchProfile(HermesToolsRepository next) {
    repository = next;
    // A pick in flight is dropped, not landed: no second list read for it.
    _backendWriting = false;
    for (final controller in _setups.values) {
      controller.switchProfile(next);
    }
    _backends?.switchProfile(next);
    _computer?.switchProfile(next);
  }

  /// Drops every typed key: sign-out.
  void clearKeys() {
    for (final controller in _setups.values) {
      controller.clearKeys();
    }
  }

  void dispose() {
    _disposed = true;
    _owners.clear();
    // Disposing drops what was typed without telling the panels, which are
    // being torn down with the screen.
    for (final controller in _setups.values) {
      controller.dispose();
    }
    _setups.clear();
    _backends?.dispose();
    _computer?.dispose();
  }
}
