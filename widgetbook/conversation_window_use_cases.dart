import 'package:flutter/material.dart';
import 'package:hermes_app/src/windows/widgets/conversation_window_toolbar.dart';
import 'package:widgetbook/widgetbook.dart';

/// The toolbar of a conversation window, shown on macOS in either viewport.
Widget _mac(Widget child) => Builder(
  builder: (context) => Theme(
    data: Theme.of(context).copyWith(platform: TargetPlatform.macOS),
    child: Align(alignment: Alignment.topCenter, child: child),
  ),
);

ConversationWindowToolbar _toolbar({
  String title = 'Plan the Lisbon trip',
  String? subtitle = 'work · hermes-4',
  bool pinned = false,
  bool enabled = true,
}) => ConversationWindowToolbar(
  title: title,
  subtitle: subtitle,
  pinned: pinned,
  onShowInMain: enabled ? () {} : null,
  onTogglePin: enabled ? () {} : null,
  onShare: enabled ? (_) {} : null,
  onAction: enabled ? (_) {} : null,
);

WidgetbookUseCase _use(String name, Widget child) =>
    WidgetbookUseCase(name: name, builder: (_) => _mac(child));

WidgetbookNode conversationWindowNode() => WidgetbookFolder(
  name: 'Conversation window',
  children: [
    WidgetbookComponent(
      name: 'ConversationWindowToolbar',
      useCases: [
        _use('Unpinned', _toolbar()),
        _use('Pinned', _toolbar(pinned: true)),
        _use(
          'Long title',
          _toolbar(
            title:
                'A chat title long enough to be cut short before the buttons '
                'at the trailing edge of the window',
          ),
        ),
        _use('No profile or model', _toolbar(subtitle: null)),
        _use(
          'Loading',
          _toolbar(title: 'Hermes', subtitle: null, enabled: false),
        ),
      ],
    ),
  ],
);
