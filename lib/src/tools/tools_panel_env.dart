import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_lock/app_lock_controller.dart';
import '../theme/breakpoints.dart';
import 'hermes_tools_repository.dart';
import 'toolset_copy.dart';
import 'toolset_installs.dart';
import 'tools_setup_registry.dart';

/// Whether there is no pull to refresh: on a desktop platform (macOS,
/// Windows, Linux) or in a window wide enough for the details beside the
/// list. "Couldn't confirm" then offers Try again.
bool toolsOnDesktop(BuildContext context) =>
    const {
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
    }.contains(Theme.of(context).platform) ||
    isWideLayout(context);

/// Opens an address outside the app.
typedef ToolsLinkLauncher = Future<bool> Function(Uri uri);

/// The system browser, never a web view inside the app.
Future<bool> launchToolsLink(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// Whether [raw] is an address the app opens: a web page, nothing else.
Uri? toolsWebLink(String? raw) {
  final uri = raw == null ? null : Uri.tryParse(raw.trim());
  if (uri == null || !uri.hasAuthority) return null;
  return uri.scheme == 'https' || uri.scheme == 'http' ? uri : null;
}

/// The Bot Screen of the profile, as far as Computer use needs it: whether it
/// is offered, a change to listen to, and a way to open its live viewer.
/// `ChatScreen` makes one only when it holds a Bot Screen controller, so a
/// Tools screen opened anywhere else shows no "Open the bot's screen".
class ToolsBotScreenLink {
  const ToolsBotScreenLink({
    required this.changes,
    required this.offered,
    required this.open,
  });

  final Listenable changes;
  final bool Function() offered;
  final VoidCallback open;
}

/// The reads the detail's panels redo when the user pulls to refresh or
/// presses Try again; each panel registers its own while it is mounted.
class ToolsRefresh {
  final _hooks = <Future<void> Function()>{};

  void add(Future<void> Function() hook) => _hooks.add(hook);

  void remove(Future<void> Function() hook) => _hooks.remove(hook);

  Future<void> run() => Future.wait([
    for (final hook in {..._hooks}) hook(),
  ]);

  final _clears = <VoidCallback>{};

  /// Registers what drops a panel's typed secrets.
  void addClear(VoidCallback hook) => _clears.add(hook);

  void removeClear(VoidCallback hook) => _clears.remove(hook);

  /// Drops every typed secret of the open details: the user signed out.
  void clearAll() {
    for (final hook in {..._clears}) {
      hook();
    }
  }
}

/// What the panels of one open detail share with the screen.
class ToolsPanelEnv {
  const ToolsPanelEnv({
    required this.repository,
    required this.installs,
    required this.ask,
    required this.launchLink,
    required this.refresh,
    required this.registry,
    required this.onWritten,
    this.botScreen,
    this.lock,
    this.locked = false,
  });

  /// Bound to the profile whose toolset this is.
  final HermesToolsRepository repository;
  final ToolsetInstalls installs;

  /// Asks a question before something runs on the server; true only for the
  /// confirming action.
  final Future<bool> Function(ToolsetQuestion question) ask;
  final ToolsLinkLauncher launchLink;
  final ToolsRefresh refresh;

  /// The controllers of the setup, which outlive the panels; they hold the
  /// write lock of a toolset and report it.
  final ToolsSetupRegistry registry;

  /// A setup write landed: the screen reads the list again.
  final VoidCallback onWritten;
  final ToolsBotScreenLink? botScreen;

  /// App Lock, which clears typed keys when it locks.
  final AppLockController? lock;

  /// Some write of this toolset is out: its own switch, a setup write, a
  /// backend pick or the permission grant (the count the registry keeps). The
  /// panels take no pick, save, install or grant until every one has ended,
  /// so writes of a toolset never overlap.
  final bool locked;

  ToolsPanelEnv withLocked({required bool busy}) => ToolsPanelEnv(
    repository: repository,
    installs: installs,
    ask: ask,
    launchLink: launchLink,
    refresh: refresh,
    registry: registry,
    onWritten: onWritten,
    botScreen: botScreen,
    lock: lock,
    locked: busy,
  );
}
