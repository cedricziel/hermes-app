import 'package:flutter/material.dart';
import 'package:hermes_app/src/widgets/adaptive_dialog.dart';
import 'package:hermes_app/src/widgets/adaptive_pickers.dart';
import 'package:hermes_app/src/widgets/adaptive_popup_menu_button.dart';
import 'package:widgetbook/widgetbook.dart';

import 'host.dart';

const _platforms = {
  'iOS': TargetPlatform.iOS,
  'macOS': TargetPlatform.macOS,
  'Android': TargetPlatform.android,
};

WidgetbookUseCase _on(
  String name,
  TargetPlatform platform,
  Widget Function(BuildContext context) builder,
) => WidgetbookUseCase(
  name: name,
  builder: (context) => Theme(
    data: Theme.of(context).copyWith(platform: platform),
    child: Builder(builder: builder),
  ),
);

List<WidgetbookUseCase> _everywhere(
  Widget Function(BuildContext context) builder,
) => [
  for (final MapEntry(:key, :value) in _platforms.entries)
    _on(key, value, builder),
];

WidgetbookNode adaptiveNode() => WidgetbookFolder(
  name: 'Adaptive controls',
  children: [
    WidgetbookComponent(
      name: 'showConfirmDialog',
      useCases: _everywhere(
        (_) => openOnShow(
          (context) => showConfirmDialog(
            context,
            title: 'Delete this chat?',
            message:
                '"Planning the offsite" and its messages will be deleted '
                'for good.',
            confirmLabel: 'Delete',
            destructive: true,
          ),
        ),
      ),
    ),
    WidgetbookComponent(
      name: 'AdaptivePopupMenuButton',
      useCases: _everywhere(
        (_) => Scaffold(
          body: Align(
            alignment: Alignment.topRight,
            child: AdaptivePopupMenuButton<String>(
              tooltip: 'More',
              icon: const Icon(Icons.more_horiz),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'rename', child: Text('Rename')),
                CheckedPopupMenuItem(
                  value: 'pin',
                  checked: true,
                  child: Text('Pinned'),
                ),
                PopupMenuDivider(),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ),
        ),
      ),
    ),
    WidgetbookComponent(
      name: 'pickTime',
      useCases: _everywhere(
        (_) => openOnShow(
          (context) =>
              pickTime(context, initial: const TimeOfDay(hour: 8, minute: 30)),
        ),
      ),
    ),
  ],
);
