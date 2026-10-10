import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// The commands the macOS menu bar offers that a screen carries out.
enum MacCommand {
  about,
  settings,
  connectionDetails,
  signOut,
  newChat,
  openInNewWindow,
  closeWindow,
  back,
  toggleSidebar,
  toggleInspector,
  find,
  pinThread,
  renameThread,
  copyTranscript,
  archiveThread,
  deleteThread,
  showMainWindow,
  help,
}

/// What a [MacCommand] does on the screen in front. A null [onInvoke] shows
/// the menu item disabled; [title] replaces the item's label, as Pin becomes
/// Unpin.
@immutable
class MacCommandHandler {
  const MacCommandHandler(this.onInvoke, {this.title});

  final VoidCallback? onInvoke;
  final String? title;

  bool get enabled => onInvoke != null;
}

/// An open window listed in the Window menu.
@immutable
class MacWindowEntry {
  const MacWindowEntry({
    required this.id,
    required this.title,
    required this.onSelect,
  });

  final String id;
  final String title;
  final VoidCallback onSelect;

  @override
  bool operator ==(Object other) =>
      other is MacWindowEntry && other.id == id && other.title == title;

  @override
  int get hashCode => Object.hash(id, title);
}

/// The handlers registered for each [MacCommand], which the menu bar reads.
///
/// Of the registrations holding a command, the one with the highest priority
/// wins, and among equals the latest. Listeners hear only of changes to what
/// the menu shows (which commands are enabled, their titles, the
/// window list), not of every new callback, so a screen rebuilding often does
/// not rebuild the menu.
class MacCommandRegistry extends ChangeNotifier {
  final _registrations = <MacCommandRegistration>[];
  List<MacWindowEntry> _windows = const [];
  Map<MacCommand, (bool, String?)> _shown = const {};
  bool _notifyScheduled = false;
  bool _disposed = false;

  /// The windows the Window menu lists below the main window.
  List<MacWindowEntry> get windows => _windows;
  set windows(List<MacWindowEntry> value) {
    if (listEquals(value, _windows)) return;
    _windows = List.unmodifiable(value);
    _scheduleNotify();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  MacCommandRegistration register(
    Map<MacCommand, MacCommandHandler> handlers, {
    int priority = 0,
  }) {
    final registration = MacCommandRegistration._(this, handlers, priority);
    _registrations.add(registration);
    _changed();
    return registration;
  }

  /// The handler the menu uses for [command], or null when no screen offers
  /// it.
  MacCommandHandler? handlerFor(MacCommand command) {
    MacCommandHandler? found;
    var best = -1 << 31;
    for (final registration in _registrations) {
      final handler = registration._handlers[command];
      if (handler != null && registration.priority >= best) {
        found = handler;
        best = registration.priority;
      }
    }
    return found;
  }

  /// Carries out [command] and says whether a handler did.
  bool invoke(MacCommand command) {
    final action = handlerFor(command)?.onInvoke;
    action?.call();
    return action != null;
  }

  void _changed() {
    final shown = {
      for (final command in MacCommand.values)
        if (handlerFor(command) case final handler?)
          command: (handler.enabled, handler.title),
    };
    if (mapEquals(shown, _shown)) return;
    _shown = shown;
    _scheduleNotify(fromScope: true);
  }

  // A scope registers while it builds, when the menu bar above it cannot be
  // marked for rebuilding, so the news waits for the end of the frame. The
  // first build at start-up runs outside any frame, so there it waits for the
  // build to return instead.
  void _scheduleNotify({bool fromScope = false}) {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase != SchedulerPhase.persistentCallbacks && !fromScope) {
      notifyListeners();
      return;
    }
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    void notify() {
      _notifyScheduled = false;
      if (!_disposed) notifyListeners();
    }

    if (phase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => notify());
    } else {
      scheduleMicrotask(notify);
    }
  }
}

/// One screen's handlers in a [MacCommandRegistry].
class MacCommandRegistration {
  MacCommandRegistration._(this._registry, this._handlers, this.priority);

  final MacCommandRegistry _registry;
  Map<MacCommand, MacCommandHandler> _handlers;
  final int priority;

  void update(Map<MacCommand, MacCommandHandler> handlers) {
    _handlers = handlers;
    _registry._changed();
  }

  void dispose() {
    if (_registry._registrations.remove(this)) _registry._changed();
  }
}

/// Offers [commands] to the menu bar while this widget is mounted and on
/// screen. It registers with the [MacCommandRegistry] of the nearest
/// [MacCommandScope.root], and does nothing without one, as off macOS.
///
/// A screen wraps its content in one, passing a [MacCommandHandler] per
/// command it can carry out now:
///
/// ```dart
/// MacCommandScope(
///   commands: {
///     MacCommand.newChat: MacCommandHandler(_newThread),
///     MacCommand.pinThread: MacCommandHandler(
///       thread == null ? null : () => _pin(thread),
///       title: thread?.pinned ?? false ? 'Unpin' : 'Pin',
///     ),
///   },
///   child: ...,
/// )
/// ```
///
/// A scope inside another, or mounted later, takes over the commands both
/// offer. A higher [priority] wins regardless of order: a separate window that
/// is key can override the main window's commands with priority 1. A scope in
/// a hidden page (an [IndexedStack] child, a covered route) offers nothing
/// until it is shown again. The Window menu's list of open windows is set
/// with [MacCommandRegistry.windows] on [registryOf].
class MacCommandScope extends StatefulWidget {
  const MacCommandScope({
    super.key,
    required this.commands,
    this.priority = 0,
    required this.child,
  });

  final Map<MacCommand, MacCommandHandler> commands;
  final int priority;
  final Widget child;

  /// Provides [registry] to the scopes below [child].
  static Widget root({
    required MacCommandRegistry registry,
    required Widget child,
  }) => _RegistryScope(registry: registry, child: child);

  static MacCommandRegistry? registryOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_RegistryScope>()?.registry;

  @override
  State<MacCommandScope> createState() => _MacCommandScopeState();
}

class _MacCommandScopeState extends State<MacCommandScope> {
  MacCommandRegistration? _registration;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final registry = MacCommandScope.registryOf(context);
    final shown =
        TickerMode.valuesOf(context).enabled && Visibility.of(context);
    if (registry == null || !shown) {
      _unregister();
    } else if (_registration == null || _registration!._registry != registry) {
      _unregister();
      _registration = registry.register(
        widget.commands,
        priority: widget.priority,
      );
    }
  }

  @override
  void didUpdateWidget(MacCommandScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    final registration = _registration;
    if (registration == null) return;
    if (widget.priority != oldWidget.priority) {
      registration.dispose();
      _registration = registration._registry.register(
        widget.commands,
        priority: widget.priority,
      );
    } else {
      registration.update(widget.commands);
    }
  }

  void _unregister() {
    _registration?.dispose();
    _registration = null;
  }

  @override
  void dispose() {
    _unregister();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _RegistryScope extends InheritedWidget {
  const _RegistryScope({required this.registry, required super.child});

  final MacCommandRegistry registry;

  @override
  bool updateShouldNotify(_RegistryScope oldWidget) =>
      registry != oldWidget.registry;
}
