import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../theme/platform_chrome.dart';
import '../../widgets/grouped_list.dart';
import 'command_row.dart';
import 'update_step_list.dart';

/// Full-width buttons share one height: 44 on Apple platforms, 48 on Material.
ButtonStyle _wide(BuildContext context) {
  final height = platformChromeOf(context) == PlatformChrome.material
      ? 48.0
      : kAppleMinTapTarget;
  return ButtonStyle(minimumSize: WidgetStatePropertyAll(Size(0, height)));
}

Widget _fullWidth(Widget button) =>
    SizedBox(width: double.infinity, child: button);

/// What the Update page's status card says. Each case carries only the data
/// its copy needs.
sealed class UpdateStatus {
  const UpdateStatus();
}

class UpdateUpToDate extends UpdateStatus {
  const UpdateUpToDate({required this.version, required this.checkedAgo});

  final String version;

  /// "just now", "2 hours ago".
  final String checkedAgo;
}

class UpdateChecking extends UpdateStatus {
  const UpdateChecking();
}

/// The check failed; [message] is Hermes' own text.
class UpdateCheckFailed extends UpdateStatus {
  const UpdateCheckFailed({required this.message});

  final String message;
}

class UpdateAvailable extends UpdateStatus {
  const UpdateAvailable({
    required this.changeCount,
    required this.currentVersion,
  });

  final int changeCount;
  final String currentVersion;
}

/// The build is newer than the stable release; updating moves it back.
class UpdateRollback extends UpdateStatus {
  const UpdateRollback({
    required this.stableVersion,
    this.changeCount,
    this.currentVersion,
  });

  final String stableVersion;

  /// Both are needed for the body line; without them it is left out.
  final int? changeCount;
  final String? currentVersion;
}

/// The app cannot apply the update here; [message] is Hermes' own text and
/// [command] what to run on the server, when Hermes gives one.
class UpdateCannotApply extends UpdateStatus {
  const UpdateCannotApply({required this.message, this.command});

  final String message;
  final String? command;
}

/// One entry of "What's new": the summary and "author · 3 days ago".
class UpdateChange {
  const UpdateChange({required this.summary, required this.byline});

  final String summary;
  final String byline;
}

/// The Update page's status: a title, a body, at most one full-width button
/// and, where it applies, the restart note. A command Hermes wants run on the
/// server sits under a "Command" header.
class UpdateStatusCard extends StatelessWidget {
  const UpdateStatusCard({
    super.key,
    required this.status,
    this.onCheckNow,
    this.onUpdate,
    this.onCopied,
  });

  final UpdateStatus status;
  final VoidCallback? onCheckNow;

  /// Without it an available update shows no button and no restart note.
  final VoidCallback? onUpdate;
  final VoidCallback? onCopied;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.hermesColors;
    final l10n = context.l10n;
    final (icon, tint) = switch (status) {
      UpdateUpToDate() => (AppIcons.checkCircleFilled, colors.success),
      UpdateChecking() => (null, scheme.onSurface),
      UpdateCheckFailed() => (AppIcons.warning, colors.warning),
      UpdateAvailable() => (AppIcons.install, scheme.onSurface),
      UpdateRollback() => (AppIcons.warning, colors.warning),
      UpdateCannotApply() => (AppIcons.info, colors.subtleText),
    };
    final title = switch (status) {
      UpdateUpToDate() => l10n.serverCareUpdateTitleUpToDate,
      UpdateChecking() => l10n.serverCareUpdateTitleChecking,
      UpdateCheckFailed() => l10n.serverCareUpdateCouldntCheck,
      UpdateAvailable() || UpdateRollback() => l10n.serverCareUpdateAvailable,
      UpdateCannotApply() => l10n.serverCareUpdateTitleOnServer,
    };
    final body = switch (status) {
      UpdateUpToDate(:final version, :final checkedAgo) =>
        l10n.serverCareUpdateBodyUpToDate(version, checkedAgo),
      UpdateChecking() => null,
      UpdateCheckFailed(:final message) => message,
      UpdateAvailable(:final changeCount, :final currentVersion) =>
        l10n.serverCareUpdateBodyChangesSince(
          l10n.serverCareUpdateChanges(changeCount),
          currentVersion,
        ),
      UpdateRollback(:final changeCount, :final currentVersion) =>
        changeCount == null || currentVersion == null
            ? null
            : l10n.serverCareUpdateBodyChangesSince(
                l10n.serverCareUpdateChanges(changeCount),
                currentVersion,
              ),
      UpdateCannotApply(:final message) => message,
    };
    final warning = switch (status) {
      UpdateRollback(:final stableVersion) =>
        l10n.serverCareUpdateRollbackWarning(stableVersion),
      _ => null,
    };
    final command = switch (status) {
      UpdateCannotApply(:final command) => command,
      _ => null,
    };
    final Widget? button = switch (status) {
      UpdateUpToDate() || UpdateCheckFailed() => _fullWidth(
        OutlinedButton(
          style: _wide(context),
          onPressed: onCheckNow,
          child: Text(l10n.serverCareCheckNow),
        ),
      ),
      UpdateAvailable() when onUpdate != null => _fullWidth(
        FilledButton(
          style: _wide(context),
          onPressed: onUpdate,
          child: Text(l10n.serverCareUpdateNow),
        ),
      ),
      UpdateRollback(:final stableVersion) when onUpdate != null => _fullWidth(
        FilledButton(
          style: _wide(context),
          onPressed: onUpdate,
          child: Text(l10n.serverCareUpdateMoveTo(stableVersion)),
        ),
      ),
      UpdateChecking() ||
      UpdateCannotApply() ||
      UpdateAvailable() ||
      UpdateRollback() => null,
    };
    // Without an action there is no restart to warn about.
    final showNote =
        onUpdate != null &&
        (status is UpdateAvailable || status is UpdateRollback);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: scheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kHermesRadius),
            side: BorderSide(color: scheme.outline),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 12,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 12,
                  children: [
                    SizedBox.square(
                      dimension: 24,
                      child: icon == null
                          ? Padding(
                              padding: const EdgeInsets.all(2),
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: tint,
                              ),
                            )
                          : ExcludeSemantics(
                              child: AppIcon(icon, size: 24, color: tint),
                            ),
                    ),
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (body != null)
                  Text(body, style: TextStyle(color: colors.subtleText)),
                if (warning != null)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 6,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: AppIcon(
                          AppIcons.warning,
                          size: 16,
                          color: colors.warning,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          warning,
                          style: TextStyle(color: colors.warning),
                        ),
                      ),
                    ],
                  ),
                ?button,
                if (showNote)
                  Text(
                    l10n.serverCareUpdateRestartNote,
                    style: TextStyle(fontSize: 13, color: colors.subtleText),
                  ),
              ],
            ),
          ),
        ),
        if (command != null)
          GroupedSection(
            header: l10n.serverCareUpdateCommandHeader,
            children: [
              Builder(
                builder: (context) => Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: GroupedMetrics.of(context).rowPadding,
                    vertical: 8,
                  ),
                  child: CommandRow(command: command, onCopied: onCopied),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// "What's new": one row per change, summary as the title and "author · 3 days
/// ago" as the subtitle. Rows do nothing when tapped.
class UpdateChangeList extends StatelessWidget {
  const UpdateChangeList({super.key, required this.changes});

  final List<UpdateChange> changes;

  @override
  Widget build(BuildContext context) => GroupedSection(
    header: context.l10n.serverCareUpdateWhatsNew,
    children: [
      for (final change in changes)
        GroupedRow(
          title: change.summary,
          titleMaxLines: null,
          subtitle: change.byline,
          subtitleMaxLines: null,
        ),
    ],
  );
}

enum UpdateOutcomeKind {
  success,
  partial,
  failed,
  unconfirmed,
  oldServerRunning,
  notBack,
}

/// How an update ended: a centred 48 pt icon, a title and a body, then the
/// buttons stacked at full width, the filled one first.
///
/// [version] is the one Hermes now runs (success, unconfirmed) or still runs
/// (failed). [items] are the things left to do after a partial update, one
/// line each.
class UpdateOutcomeCard extends StatelessWidget {
  const UpdateOutcomeCard({
    super.key,
    required this.kind,
    this.version,
    this.items = const [],
    this.runningVersion,
    this.installedVersion,
    this.detailLines = const [],
    this.onDone,
    this.onTryAgain,
    this.onCheckAgain,
    this.onKeepWaiting,
    this.onDismiss,
  });

  final UpdateOutcomeKind kind;
  final String? version;
  final List<String> items;
  final String? runningVersion;
  final String? installedVersion;
  final List<String> detailLines;
  final VoidCallback? onDone;
  final VoidCallback? onTryAgain;
  final VoidCallback? onCheckAgain;
  final VoidCallback? onKeepWaiting;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.hermesColors;
    final l10n = context.l10n;
    final (icon, tint) = switch (kind) {
      UpdateOutcomeKind.success => (AppIcons.checkCircleFilled, colors.success),
      UpdateOutcomeKind.partial ||
      UpdateOutcomeKind.oldServerRunning ||
      UpdateOutcomeKind.notBack => (AppIcons.warningRounded, colors.warning),
      UpdateOutcomeKind.failed => (AppIcons.errorFilled, scheme.error),
      UpdateOutcomeKind.unconfirmed => (AppIcons.info, colors.subtleText),
    };
    final title = switch (kind) {
      UpdateOutcomeKind.success => l10n.serverCareUpdateTitleUpToDate,
      UpdateOutcomeKind.partial => l10n.serverCareUpdateOutcomePartialTitle,
      UpdateOutcomeKind.failed => l10n.serverCareUpdateOutcomeFailedTitle,
      UpdateOutcomeKind.unconfirmed =>
        l10n.serverCareUpdateOutcomeBackNotConfirmedTitle,
      UpdateOutcomeKind.oldServerRunning =>
        l10n.serverCareUpdateOutcomeOldServerTitle,
      UpdateOutcomeKind.notBack => l10n.serverCareUpdateOutcomeNotBackTitle,
    };
    final body = switch (kind) {
      UpdateOutcomeKind.success || UpdateOutcomeKind.unconfirmed =>
        version == null
            ? null
            : l10n.serverCareUpdateOutcomeNowRunning(version!),
      UpdateOutcomeKind.partial => null,
      UpdateOutcomeKind.failed =>
        version == null
            ? null
            : l10n.serverCareUpdateOutcomeStillRunning(version!),
      UpdateOutcomeKind.oldServerRunning =>
        l10n.serverCareUpdateOutcomeRestartToFinish,
      UpdateOutcomeKind.notBack => l10n.serverCareUpdateOutcomeNotBackHint,
    };
    final buttons = <Widget>[
      switch (kind) {
        UpdateOutcomeKind.success ||
        UpdateOutcomeKind.partial ||
        UpdateOutcomeKind.failed ||
        UpdateOutcomeKind.unconfirmed => _fullWidth(
          FilledButton(
            style: _wide(context),
            onPressed: onDone,
            child: Text(l10n.serverCareUpdateOutcomeDone),
          ),
        ),
        UpdateOutcomeKind.oldServerRunning => _fullWidth(
          FilledButton(
            style: _wide(context),
            onPressed: onCheckAgain,
            child: Text(l10n.serverCareUpdateOutcomeCheckAgain),
          ),
        ),
        UpdateOutcomeKind.notBack => _fullWidth(
          FilledButton(
            style: _wide(context),
            onPressed: onKeepWaiting,
            child: Text(l10n.serverCareUpdateOutcomeKeepWaiting),
          ),
        ),
      },
      if (kind == UpdateOutcomeKind.failed)
        _fullWidth(
          TextButton(
            style: _wide(context),
            onPressed: onTryAgain,
            child: Text(l10n.serverCareTryAgain),
          ),
        ),
      if (kind == UpdateOutcomeKind.notBack)
        _fullWidth(
          TextButton(
            style: _wide(context),
            onPressed: onDismiss,
            child: Text(l10n.serverCareUpdateOutcomeDismiss),
          ),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        ExcludeSemantics(
          child: Center(child: AppIcon(icon, size: 48, color: tint)),
        ),
        const SizedBox(height: 12),
        Semantics(
          header: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
        ),
        if (body != null) ...[
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.subtleText),
          ),
        ],
        for (final item in items) ...[
          const SizedBox(height: 8),
          Text(item, textAlign: TextAlign.center),
        ],
        if (kind == UpdateOutcomeKind.oldServerRunning)
          GroupedSection(
            children: [
              GroupedRow(
                title: l10n.serverCareUpdateOutcomeRunningNow,
                value: runningVersion,
              ),
              GroupedRow(
                title: l10n.serverCareUpdateOutcomeInstalled,
                value: installedVersion,
              ),
            ],
          ),
        if (detailLines.isNotEmpty)
          GroupedSection(
            children: [UpdateDetailsDisclosure(lines: detailLines)],
          ),
        const SizedBox(height: 24),
        for (final (i, button) in buttons.indexed) ...[
          if (i > 0) const SizedBox(height: 8),
          button,
        ],
      ],
    );
  }
}
