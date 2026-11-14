import 'package:flutter/material.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/server_care/update_actions.dart';
import 'package:hermes_app/src/server_care/widgets/server_restart_banner.dart';
import 'package:hermes_app/src/server_care/widgets/update_confirm_dialog.dart';
import 'package:hermes_app/src/server_care/widgets/update_run_view.dart';
import 'package:hermes_app/src/server_care/widgets/update_status_card.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';
import 'package:hermes_app/src/widgets/settings_scaffold.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

// The Update page while an update runs and after it, one use case per phase,
// plus the restart banner. The copy is the screen's own (ARB keys), so a
// German check here is a German check of the screen.

Widget _largest(Widget child) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: const TextScaler.linear(2)),
    child: child,
  ),
);

Widget _reducedMotion(Widget child) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child,
  ),
);

void _nothing() {}

const _installLog = [
  'Fetching origin',
  'Updating 4e1c9a2..b7d03f1',
  'Fast-forward',
  ' 14 files changed, 311 insertions(+), 42 deletions(-)',
  'Installing dependencies',
  'Resolved 96 packages in 1.2s',
];

/// The page as the app builds it: a settings page pushed over Server, with the
/// run's view as its only content.
Widget _page(UpdateRunView view, {bool detailsOpen = false}) => pushed(
  Builder(
    builder: (context) => SettingsScaffold(
      title: context.l10n.serverCareUpdatePageTitle,
      previousTitle: context.l10n.serverCareTitle,
      body: GroupedListView(
        children: [
          UpdateRunBody(
            view: view,
            detailsInitiallyOpen: detailsOpen,
            onDone: _nothing,
            onTryAgain: _nothing,
            onCheckAgain: _nothing,
            onKeepWaiting: _nothing,
            onDismiss: _nothing,
          ),
        ],
      ),
    ),
  ),
);

/// The question open over the page's status card, as the screen shows it.
Widget _confirmation({required int replies, required int conversations}) =>
    Stack(
      fit: StackFit.expand,
      children: [
        pushed(
          Builder(
            builder: (context) => SettingsScaffold(
              title: context.l10n.serverCareUpdatePageTitle,
              previousTitle: context.l10n.serverCareTitle,
              body: GroupedListView(
                children: [
                  UpdateStatusCard(
                    status: const UpdateAvailable(
                      changeCount: 12,
                      currentVersion: '0.22.2',
                    ),
                    onUpdate: _nothing,
                  ),
                ],
              ),
            ),
          ),
        ),
        Builder(
          builder: (context) {
            final l10n = context.l10n;
            return Container(
              color: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.3),
              alignment: Alignment.center,
              child: UpdateConfirmDialog(
                title: l10n.serverCareUpdateConfirmTitle,
                lines: updateConfirmationLines(
                  l10n,
                  replies: replies,
                  conversations: conversations,
                ),
                confirmLabel: l10n.serverCareUpdateConfirmAction,
                cancelLabel: l10n.serverCareCancel,
              ),
            );
          },
        ),
      ],
    );

List<WidgetbookUseCase> _phase(String name, UpdateRunView view) => [
  WidgetbookUseCase(name: name, builder: (_) => _page(view)),
];

Widget _bannerOver(Widget banner) => Builder(
  builder: (context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Material(
        color: Theme.of(context).colorScheme.surface,
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 56,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Kanban',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
          ),
        ),
      ),
      banner,
      const Expanded(child: Center(child: Text('Board'))),
    ],
  ),
);

List<WidgetbookNode> serverCareUpdateRunNodes() => [
  WidgetbookComponent(
    name: 'Update page, running',
    useCases: [
      WidgetbookUseCase(
        name: 'Confirming, nothing running',
        builder: (_) => _confirmation(replies: 0, conversations: 0),
      ),
      WidgetbookUseCase(
        name: 'Confirming, replies and conversations',
        builder: (_) => _confirmation(replies: 2, conversations: 3),
      ),
      WidgetbookUseCase(
        name: 'Confirming, largest text',
        builder: (_) => _largest(_confirmation(replies: 1, conversations: 2)),
      ),
      ..._phaseCases(),
    ],
  ),
  WidgetbookComponent(
    name: 'Update page, outcomes',
    useCases: [
      ..._phase(
        'Success',
        const UpdateRunOutcome(
          kind: UpdateOutcomeKind.success,
          version: '0.23.0',
        ),
      ),
      ..._phase(
        'Partial',
        const UpdateRunOutcome(
          kind: UpdateOutcomeKind.partial,
          items: [
            'The Telegram channel needs to be paired again.',
            'One skill could not be updated.',
          ],
        ),
      ),
      WidgetbookUseCase(
        name: 'Partial, largest text',
        builder: (_) => _largest(
          _page(
            const UpdateRunOutcome(
              kind: UpdateOutcomeKind.partial,
              items: [
                'The Telegram channel needs to be paired again.',
                'One skill could not be updated.',
              ],
            ),
          ),
        ),
      ),
      ..._phase(
        'Failed',
        const UpdateRunOutcome(
          kind: UpdateOutcomeKind.failed,
          version: '0.22.2',
          detailLines: _installLog,
        ),
      ),
      WidgetbookUseCase(
        name: 'Failed, details open',
        builder: (_) => _page(
          const UpdateRunOutcome(
            kind: UpdateOutcomeKind.failed,
            version: '0.22.2',
            detailLines: _installLog,
          ),
          detailsOpen: true,
        ),
      ),
      WidgetbookUseCase(
        name: 'Failed, largest text',
        builder: (_) => _largest(
          _page(
            const UpdateRunOutcome(
              kind: UpdateOutcomeKind.failed,
              version: '0.22.2',
              detailLines: _installLog,
            ),
          ),
        ),
      ),
      ..._phase(
        'Interrupted, the old version still runs',
        const UpdateRunOutcome(
          kind: UpdateOutcomeKind.failed,
          version: '0.22.2',
        ),
      ),
      ..._phase(
        "Unknown, can't confirm",
        const UpdateRunOutcome(
          kind: UpdateOutcomeKind.unconfirmed,
          version: '0.23.0',
        ),
      ),
      ..._phase(
        'Unknown, no version',
        const UpdateRunOutcome(kind: UpdateOutcomeKind.unconfirmed),
      ),
      ..._phase(
        'Old server still running',
        const UpdateRunOutcome(
          kind: UpdateOutcomeKind.oldServerRunning,
          runningVersion: '0.22.2',
          installedVersion: '0.23.0',
        ),
      ),
      WidgetbookUseCase(
        name: 'Old server still running, largest text',
        builder: (_) => _largest(
          _page(
            const UpdateRunOutcome(
              kind: UpdateOutcomeKind.oldServerRunning,
              runningVersion: '0.22.2',
              installedVersion: '0.23.0',
            ),
          ),
        ),
      ),
      ..._phase(
        'Not back, Keep waiting',
        const UpdateRunOutcome(kind: UpdateOutcomeKind.notBack),
      ),
      WidgetbookUseCase(
        name: 'Not back, largest text',
        builder: (_) => _largest(
          _page(const UpdateRunOutcome(kind: UpdateOutcomeKind.notBack)),
        ),
      ),
      ..._phase(
        'Refused, with the command',
        const UpdateRunRefused(
          message:
              'Hermes runs in Docker here. Pull the new image and recreate '
              'the container to update it.',
          command: 'docker compose pull && docker compose up -d',
        ),
      ),
      ..._phase(
        'Refused, message only',
        const UpdateRunRefused(
          message:
              'Hermes updates are managed outside this dashboard in '
              'containerized environments.',
        ),
      ),
      ..._phase(
        'Unauthorized',
        const UpdateRunOutcome(kind: UpdateOutcomeKind.unauthorized),
      ),
      WidgetbookUseCase(
        name: 'Unauthorized, largest text',
        builder: (_) => _largest(
          _page(const UpdateRunOutcome(kind: UpdateOutcomeKind.unauthorized)),
        ),
      ),
    ],
  ),
  WidgetbookComponent(
    name: 'Restart banner over a page',
    useCases: [
      ...onEachPlatform(
        'Restarting',
        (_) => _bannerOver(ServerRestartBanner.restarting(onTap: _nothing)),
      ),
      WidgetbookUseCase(
        name: 'Ready',
        builder: (_) => _bannerOver(
          ServerRestartBanner.ready(
            version: '0.23.0',
            onClose: _nothing,
            onAutoDismiss: _nothing,
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Ready, reduced motion (stays until closed)',
        builder: (_) => _reducedMotion(
          _bannerOver(
            ServerRestartBanner.ready(
              version: '0.23.0',
              onClose: _nothing,
              onAutoDismiss: _nothing,
            ),
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Restarting, largest text',
        builder: (_) => _largest(
          _bannerOver(ServerRestartBanner.restarting(onTap: _nothing)),
        ),
      ),
      WidgetbookUseCase(
        name: 'Ready, largest text',
        builder: (_) => _largest(
          _bannerOver(
            ServerRestartBanner.ready(
              version: '0.23.0',
              onClose: _nothing,
              onAutoDismiss: _nothing,
            ),
          ),
        ),
      ),
    ],
  ),
];

List<WidgetbookUseCase> _phaseCases() => [
  ..._phase(
    'Starting',
    const UpdateRunProgress(stage: UpdateProgressStage.starting),
  ),
  ..._phase(
    'Updating, with details',
    const UpdateRunProgress(
      stage: UpdateProgressStage.installing,
      detailLines: _installLog,
    ),
  ),
  WidgetbookUseCase(
    name: 'Updating, details open',
    builder: (_) => _page(
      const UpdateRunProgress(
        stage: UpdateProgressStage.installing,
        detailLines: _installLog,
      ),
      detailsOpen: true,
    ),
  ),
  ..._phase(
    'Restarting',
    const UpdateRunProgress(stage: UpdateProgressStage.restarting),
  ),
  ..._phase(
    'Verifying',
    const UpdateRunProgress(stage: UpdateProgressStage.checking),
  ),
  WidgetbookUseCase(
    name: 'Restarting, largest text',
    builder: (_) => _largest(
      _page(const UpdateRunProgress(stage: UpdateProgressStage.restarting)),
    ),
  ),
];
