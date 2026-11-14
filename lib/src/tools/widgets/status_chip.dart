import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../widgets/app_badge.dart';
import '../tools_models.dart';

/// What a provider or a terminal backend can do now, as the Tools screens
/// say it. The one place that maps a status to its words, icon and colour.
enum ToolsStatus {
  ready,
  needsKey,
  needsSignIn,
  needsInstall,

  /// What a provider with a status this app does not know reads as. A
  /// backend with an unknown status is [unusable] instead.
  needsSetup,
  unusable;

  static ToolsStatus fromProvider(ToolsetProviderStatus status) =>
      switch (status) {
        ToolsetProviderStatus.ready => ready,
        ToolsetProviderStatus.needsKeys => needsKey,
        ToolsetProviderStatus.needsAuth => needsSignIn,
        ToolsetProviderStatus.needsSetup => needsSetup,
      };

  static ToolsStatus fromBackend(BackendStatus status) => switch (status) {
    BackendStatus.ready => ready,
    BackendStatus.needsSetup => needsSetup,
    BackendStatus.unavailable => unusable,
  };

  String label(AppLocalizations l10n) => switch (this) {
    ready => l10n.toolsChipReady,
    needsKey => l10n.toolsChipNeedsKey,
    needsSignIn => l10n.toolsChipNeedsSignIn,
    needsInstall => l10n.toolsChipNeedsInstall,
    needsSetup => l10n.toolsNeedsSetup,
    unusable => l10n.toolsChipCantUse,
  };

  AppIconSet get icon => switch (this) {
    ready => AppIcons.check,
    needsKey => AppIcons.key,
    needsSignIn => AppIcons.signIn,
    needsInstall => AppIcons.download,
    needsSetup => AppIcons.warning,
    unusable => AppIcons.blocked,
  };

  Color color(BuildContext context) {
    final colors = context.hermesColors;
    return switch (this) {
      ready => colors.success,
      needsKey || needsSignIn || needsInstall || needsSetup => colors.warning,
      unusable => colors.subtleText,
    };
  }
}

/// The kit's small tinted badge with an icon and words, so a status is never
/// told by its colour alone. Long words wrap at large text sizes.
class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});

  final ToolsStatus status;

  @override
  Widget build(BuildContext context) => AppBadge.tinted(
    label: status.label(context.l10n),
    color: status.color(context),
    icon: status.icon,
  );
}
