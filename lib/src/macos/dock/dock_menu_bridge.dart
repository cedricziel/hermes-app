import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../mac_app.dart';

/// What the Dock menu shows. Only [ready] carries chats; a locked menu offers
/// New Chat alone, and an [off] one just Show Main Window.
enum DockMenuState { off, locked, ready }

/// A chat as the Dock menu lists it.
typedef DockChat = ({String id, String profile, String title});

/// A choice made in the Dock menu.
sealed class DockMenuAction {
  const DockMenuAction();
}

class DockNewChat extends DockMenuAction {
  const DockNewChat();
}

class DockOpenChat extends DockMenuAction {
  const DockOpenChat(this.id, this.profile);
  final String id;
  final String profile;
}

/// The macOS runner's Dock menu, over the app channel. Does nothing off
/// macOS, and swallows what a missing or failing runner throws.
class DockMenuBridge {
  DockMenuBridge({bool? enabled})
    : enabled =
          enabled ?? (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS);

  final bool enabled;

  Stream<DockMenuAction> get actions {
    if (!enabled) return const Stream.empty();
    return MacApp.dockMenuCalls
        .map(_parse)
        .where((action) => action != null)
        .cast<DockMenuAction>();
  }

  Future<void> update(DockMenuState state, List<DockChat> chats) async {
    if (!enabled) return;
    try {
      await MacApp.setDockMenu({
        'state': state.name,
        'chats': [
          for (final chat in chats)
            {'id': chat.id, 'profile': chat.profile, 'title': chat.title},
        ],
      });
    } on PlatformException {
      return;
    } on MissingPluginException {
      return;
    }
  }

  static DockMenuAction? _parse(MethodCall call) {
    switch (call.method) {
      case 'dockNewChat':
        return const DockNewChat();
      case 'dockOpenChat':
        final arguments = call.arguments;
        if (arguments is! Map) return null;
        final id = arguments['id'];
        final profile = arguments['profile'];
        return id is String && profile is String
            ? DockOpenChat(id, profile)
            : null;
    }
    return null;
  }
}
