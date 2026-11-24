import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../macos/mac_toolbar.dart';
import '../../widgets/adaptive_popup_menu_button.dart';
import '../../widgets/named_popup_menu_button.dart';
import 'thread_actions_menu.dart' show ExportJsonOffer;

enum _More { showFiles, copyTranscript, exportJson, connection }

/// The "…" button of a compact Mac chat window and its menu: Show Files (when
/// [onShowFiles] is set), Copy Transcript (disabled while [onCopyTranscript]
/// is null), Export Chat as JSON… (when [exportJson] is set; disabled while an
/// export runs) and Connection Details.
class MacChatMoreMenu extends StatelessWidget {
  const MacChatMoreMenu({
    super.key,
    required this.onShowConnection,
    this.onCopyTranscript,
    this.exportJson,
    this.onShowFiles,
    this.controller,
  });

  final VoidCallback onShowConnection;
  final VoidCallback? onCopyTranscript;
  final ExportJsonOffer? exportJson;
  final VoidCallback? onShowFiles;

  /// Opens the menu from outside, for a catalog that shows it open.
  final AdaptiveMenuController? controller;

  @override
  Widget build(BuildContext context) {
    final onCopyTranscript = this.onCopyTranscript;
    return NamedPopupMenuButton<_More>(
      key: const Key('toolbar-more'),
      controller: controller,
      label: 'More',
      icon: AppIcons.more,
      iconSize: 18,
      color: context.hermesColors.subtleText,
      padding: EdgeInsets.zero,
      style: macToolbarButtonStyle(context),
      onSelected: (item) => switch (item) {
        _More.showFiles => onShowFiles?.call(),
        _More.copyTranscript => onCopyTranscript?.call(),
        _More.exportJson => exportJson?.onSelected(),
        _More.connection => onShowConnection(),
      },
      itemBuilder: (_) => [
        if (onShowFiles != null)
          AdaptiveMenuItem(
            value: _More.showFiles,
            shortcut: '⇧⌘F',
            child: const Text('Show Files'),
          ),
        AdaptiveMenuItem(
          value: _More.copyTranscript,
          enabled: onCopyTranscript != null,
          child: const Text('Copy Transcript'),
        ),
        if (exportJson case final offer?)
          AdaptiveMenuItem(
            value: _More.exportJson,
            enabled: offer.enabled,
            child: const Text('Export Chat as JSON…'),
          ),
        const AdaptiveMenuItem(
          value: _More.connection,
          child: Text('Connection Details'),
        ),
      ],
    );
  }
}
