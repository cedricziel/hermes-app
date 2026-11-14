import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import '../../../theme/app_icons.dart';
import '../../../theme/hermes_theme.dart';
import 'needs_you_models.dart';

/// [size] grown with the text size, so an icon keeps its place beside text.
double needsYouIconSize(BuildContext context, double size) =>
    MediaQuery.textScalerOf(context).scale(size);

/// From twice the text size a row has no room beside its text: the header
/// drops its icon and a target's Open goes below the target.
bool needsYouLargeText(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(1) >= 2;

/// The look of the card's outlined buttons: a border that shows on the card in
/// both themes (the theme's own outline is as dark as the card in dark mode).
ButtonStyle needsYouOutlinedStyle(BuildContext context) =>
    OutlinedButton.styleFrom(
      side: BorderSide(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
      ),
    );

/// A plain warning line: icon and words in the warning colour, never colour
/// alone. Not a banner; it sits in the card it belongs to.
class NeedsYouNoticeLine extends StatelessWidget {
  const NeedsYouNoticeLine({super.key, required this.text, this.icon});

  final String text;
  final AppIconSet? icon;

  @override
  Widget build(BuildContext context) {
    final color = context.hermesColors.warning;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: AppIcon(
            icon ?? AppIcons.warning,
            size: needsYouIconSize(context, 16),
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: color, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}

/// The text of [Duration] left on an operation, as "Expires in 4 min".
String needsYouExpiresText(BuildContext context, Duration left) {
  final l10n = context.l10n;
  if (left < const Duration(minutes: 1)) {
    return l10n.chatActivityNeedsYouExpiresSoon;
  }
  return l10n.chatActivityNeedsYouExpires((left.inSeconds / 60).ceil());
}

String _statusText(BuildContext context, ConnectorTargetStatus status) {
  final l10n = context.l10n;
  return switch (status) {
    ConnectorTargetStatus.waiting => l10n.chatActivityNeedsYouTargetWaiting,
    ConnectorTargetStatus.signedIn => l10n.chatActivityNeedsYouTargetSignedIn,
    ConnectorTargetStatus.failed => l10n.chatActivityNeedsYouTargetFailed,
  };
}

/// The line that says where a billing page lives: "Opens verify.example.com",
/// or that this app cannot open the link.
class _HostLine extends StatelessWidget {
  const _HostLine({required this.host});

  final String? host;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final host = this.host;
    if (host == null) {
      return NeedsYouNoticeLine(text: l10n.chatActivityNeedsYouLinkUnavailable);
    }
    final subtle = context.hermesColors.subtleText;
    return Row(
      children: [
        AppIcon(
          AppIcons.openBrowser,
          size: needsYouIconSize(context, 16),
          color: subtle,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            l10n.chatActivityNeedsYouOpensHost(host),
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: subtle),
          ),
        ),
      ],
    );
  }
}

/// The verification code in a bordered box. The text is selectable and
/// reachable by focus, so a screen reader reads it only when it gets there.
class _CodeBox extends StatelessWidget {
  const _CodeBox({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: context.l10n.chatActivityNeedsYouCodeLabel,
      child: Container(
        key: const Key('needs-you-code'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.outline),
        ),
        child: SelectableText(
          code,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontFamily: 'monospace',
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}

/// The body of a billing request: what to do, where the page lives (before
/// the code, so a large text size cannot push it out of view) and the code.
class BillingNeedsYouBody extends StatelessWidget {
  const BillingNeedsYouBody({super.key, required this.model});

  final BillingBodyModel model;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(context.l10n.chatActivityNeedsYouBillingIntro),
      const SizedBox(height: 10),
      _HostLine(host: model.host),
      const SizedBox(height: 10),
      _CodeBox(code: model.code),
    ],
  );
}

/// One service a sign-in waits on: its name, where it stands and, when
/// [onOpen] is given, its own Open button.
class _TargetRow extends StatelessWidget {
  const _TargetRow({required this.target, this.onOpen});

  final ConnectorTargetModel target;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.hermesColors;
    final (icon, color) = switch (target.status) {
      ConnectorTargetStatus.waiting => (AppIcons.waiting, colors.subtleText),
      ConnectorTargetStatus.signedIn => (AppIcons.checkCircle, colors.success),
      ConnectorTargetStatus.failed => (AppIcons.warning, colors.warning),
    };
    final large = needsYouLargeText(context);
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                target.name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: AppIcon(
                      icon,
                      size: needsYouIconSize(context, 14),
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _statusText(context, target.status),
                      style: theme.textTheme.bodySmall?.copyWith(color: color),
                    ),
                  ),
                ],
              ),
              if (target.detail case final detail?)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: SelectableText(
                    detail,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.subtleText,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (target.openable && !large)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: OutlinedButton(
              style: needsYouOutlinedStyle(context),
              onPressed: onOpen,
              child: Text(context.l10n.chatActivityNeedsYouConnectorOpen),
            ),
          ),
      ],
    );
    if (!large || !target.openable) return row;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row,
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton(
            style: needsYouOutlinedStyle(context),
            onPressed: onOpen,
            child: Text(context.l10n.chatActivityNeedsYouConnectorOpen),
          ),
        ),
      ],
    );
  }
}

/// The body of a connector sign-in: every target with its state, then the
/// deadline. [onOpen] adds an Open button to each openable target; null
/// leaves them to the dock's action row.
class ConnectorNeedsYouBody extends StatelessWidget {
  const ConnectorNeedsYouBody({
    super.key,
    required this.model,
    this.onOpen,
    this.openEnabled = true,
  });

  final ConnectorBodyModel model;
  final ValueChanged<String>? onOpen;

  /// Whether the per-target Open buttons can run.
  final bool openEnabled;

  @override
  Widget build(BuildContext context) {
    final expiresIn = model.expiresIn;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, target) in model.targets.indexed) ...[
          if (index > 0) const SizedBox(height: 12),
          _TargetRow(
            target: ConnectorTargetModel(
              name: target.name,
              status: target.status,
              detail: target.detail,
              openable: target.openable && onOpen != null,
            ),
            onOpen: openEnabled && onOpen != null
                ? () => onOpen!(target.name)
                : null,
          ),
        ],
        if (expiresIn != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              AppIcon(
                AppIcons.schedule,
                size: needsYouIconSize(context, 16),
                color: context.hermesColors.subtleText,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  needsYouExpiresText(context, expiresIn),
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: context.hermesColors.subtleText),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// The body of a reclaimed chat or one whose restore failed: what happened,
/// then the server's own reason when it gave one.
class ReclaimNeedsYouBody extends StatelessWidget {
  const ReclaimNeedsYouBody({
    super.key,
    required this.model,
    this.restoreFailed = false,
  });

  final ReclaimBodyModel model;
  final bool restoreFailed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final reason = model.reason;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          restoreFailed
              ? l10n.chatActivityNeedsYouResumeBody
              : l10n.chatActivityNeedsYouReclaimBody,
        ),
        if (reason != null && reason.isNotEmpty) ...[
          const SizedBox(height: 8),
          SelectableText(
            reason,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: context.hermesColors.subtleText),
          ),
        ],
      ],
    );
  }
}
