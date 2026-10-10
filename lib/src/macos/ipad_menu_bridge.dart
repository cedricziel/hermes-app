import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_otel/flutter_otel.dart' show AppEventLogger;

import '../telemetry/breadcrumbs.dart';
import 'mac_commands.dart';
import 'menu_layout.dart';

/// Puts [menuLayout] into the iPadOS menu bar and the list shown while ⌘ is
/// held, through the runner's `hermes_app/menu` channel.
///
/// The runner owns the menu items; this sends the layout once and, whenever
/// what the screens in front offer changes, which commands are enabled and
/// what they are titled. It reports back the item or key the user used, and
/// the command runs through [registry] like a Mac menu item does. A disabled
/// item's shortcut is not taken by UIKit, so the key reaches the app as it
/// would without the menu.
class IpadMenuBridge {
  IpadMenuBridge({
    required this.registry,
    this.breadcrumbs = Breadcrumbs.none,
    required this.events,
    MethodChannel? channel,
  }) : _channel = channel ?? const MethodChannel('hermes_app/menu');

  final MacCommandRegistry registry;
  final Breadcrumbs breadcrumbs;

  /// Read for each event, as the connection a logger belongs to can change.
  final AppEventLogger Function() events;
  final MethodChannel _channel;

  late final _commands = {
    for (final section in menuLayout)
      for (final group in section.groupsOn(MenuPlatform.ipad))
        for (final entry in group) entry.command.name: entry,
  };

  void start() {
    _channel.setMethodCallHandler(_onCall);
    registry.addListener(_sendState);
    unawaited(_send('layout', 'setLayout', _layout()));
    _sendState();
  }

  void dispose() {
    registry.removeListener(_sendState);
    _channel.setMethodCallHandler(null);
  }

  Future<void> _onCall(MethodCall call) async {
    if (call.method != 'invoke') throw MissingPluginException();
    final command = _commands[call.arguments]?.command;
    if (command == null ||
        !(registry.handlerFor(command)?.enabled ?? false) ||
        _composing()) {
      return;
    }
    breadcrumbs('menu.command', {
      'command': command.name,
      'platform': 'ipados',
    });
    registry.invoke(command);
  }

  /// Whether the focused text field holds marked text. UIKit takes the chord
  /// even then, and ⌘N must not open a chat while the user is still choosing a
  /// candidate in an input method.
  bool _composing() {
    final field = FocusManager.instance.primaryFocus?.context
        ?.findAncestorStateOfType<EditableTextState>();
    final range = field?.textEditingValue.composing;
    return range != null && range.isValid && !range.isCollapsed;
  }

  void _sendState() {
    final states = {
      for (final MapEntry(key: name, value: entry) in _commands.entries)
        name: {
          'enabled': registry.handlerFor(entry.command)?.enabled ?? false,
          'title': registry.handlerFor(entry.command)?.title ?? entry.label,
        },
    };
    unawaited(_send('state', 'setState', {'states': states}));
  }

  Future<void> _send(String operation, String method, Object arguments) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on Object catch (error) {
      try {
        events()('ipad_menu.sync_failed', {
          'operation': operation,
          'error.type': error.runtimeType.toString(),
        });
      } on Object {
        // Telemetry must not take the app down with it.
      }
    }
  }

  Map<String, Object> _layout() => {
    'sections': [
      for (final section in menuLayout)
        {
          'id': section.id,
          'label': section.label,
          'groups': [
            for (final group in section.groupsOn(MenuPlatform.ipad))
              [for (final entry in group) _item(entry)],
          ],
        },
    ],
  };

  static Map<String, Object> _item(MenuEntry entry) {
    final chord = entry.shortcutOn(MenuPlatform.ipad);
    final input = chord?.trigger.keyLabel.toLowerCase();
    return {
      'command': entry.command.name,
      'label': entry.label,
      if (chord != null && input != null && input.length == 1) ...{
        'input': input,
        'modifiers': [
          if (chord.meta) 'command',
          if (chord.shift) 'shift',
          if (chord.alt) 'alternate',
          if (chord.control) 'control',
        ],
      },
    };
  }
}
