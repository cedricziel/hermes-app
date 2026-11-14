import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';
import '../app_lock/app_lock_controller.dart';
import '../models/model_provider_option.dart';
import '../models/widgets/model_picker.dart';
import '../theme/breakpoints.dart';
import '../widgets/adaptive_sheet.dart';
import '../widgets/settings_scaffold.dart';
import 'provider_models.dart';
import 'provider_setup_controller.dart';
import 'provider_view_mapper.dart';
import 'widgets/default_model_step.dart' as step_widget;
import 'widgets/provider_alerts.dart';

/// Opens a link Hermes sent after the link check; false when it could not be
/// opened.
typedef ProviderLinkLauncher = Future<bool> Function(Uri uri);

/// How a connect sheet ended.
enum ProviderSheetResult {
  closed,

  /// "Use an Anthropic account instead": the screen goes on to the server
  /// command page.
  useAccount,
}

/// What the connect sheets need from the screen that opens them.
class ProviderFlowServices {
  const ProviderFlowServices({
    required this.controller,
    required this.profileLabel,
    required this.openLink,
    required this.startChatting,
    this.appLock,
  });

  final ProviderSetupController controller;
  final String profileLabel;

  /// Opens an address that passed the link check.
  final Future<void> Function(Uri uri) openLink;

  /// "Start chatting": the screen closes what is open and leaves.
  final VoidCallback startChatting;

  /// Typed keys are cleared when it locks.
  final AppLockController? appLock;
}

/// Shows a connect form or step the way the design says: a full-screen
/// dialog on Android, a dialog on macOS and wide windows (never a bottom
/// sheet there), a page sheet on other phones.
Future<ProviderSheetResult?> showProviderSheet(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  final platform = Theme.of(context).platform;
  if (platform == TargetPlatform.android && !isWideLayout(context)) {
    return Navigator.of(context).push(
      MaterialPageRoute<ProviderSheetResult>(
        fullscreenDialog: true,
        builder: builder,
      ),
    );
  }
  return showAdaptiveSheet<ProviderSheetResult>(
    context,
    maxWidth: 480,
    builder: (sheet) {
      final dialog =
          platform == TargetPlatform.macOS ||
          isWideLayout(sheet) ||
          MediaQuery.sizeOf(sheet).width > 640;
      final height = MediaQuery.sizeOf(sheet).height;
      return SizedBox(
        height: dialog
            ? (height - 96).clamp(320, 640).toDouble()
            : height * .94,
        child: builder(sheet),
      );
    },
  );
}

/// Escape closes a form and Return does its primary action, on desktop only:
/// a phone has no keyboard chords to claim.
class ProviderSheetKeys extends StatelessWidget {
  const ProviderSheetKeys({
    super.key,
    required this.child,
    required this.onSubmit,
  });

  final Widget child;

  /// Does what the primary button does now; null when there is none.
  final VoidCallback? onSubmit;

  static bool _desktop(TargetPlatform p) =>
      p == TargetPlatform.macOS ||
      p == TargetPlatform.windows ||
      p == TargetPlatform.linux;

  @override
  Widget build(BuildContext context) {
    if (!_desktop(Theme.of(context).platform)) return child;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).maybePop(),
        const SingleActivator(LogicalKeyboardKey.enter): ?onSubmit,
      },
      child: child,
    );
  }
}

/// Clears typed text when App Lock locks, and when the owner goes away.
class SecretFieldsLock {
  SecretFieldsLock(this._lock, this._clear) {
    _lock?.addListener(_check);
  }

  final AppLockController? _lock;
  final VoidCallback _clear;

  void _check() {
    if (_lock?.locked == true) _clear();
  }

  void dispose() => _lock?.removeListener(_check);
}

/// Pops the route [context] belongs to, but only while it is still the one on
/// top: a sheet that was already closed (Cancel, Escape, Keep) must not pop
/// again, or the second pop would close the screen under it.
void popIfCurrent(BuildContext context, [Object? result]) {
  if (ModalRoute.of(context)?.isCurrent == true) {
    Navigator.of(context).pop(result);
  }
}

/// Saves [model] of [providerId] as the profile's default. An expensive model
/// asks first, with Hermes' own sentence; only "Use it anyway" resends.
Future<DefaultSetOutcome> saveDefaultModel(
  BuildContext context,
  ProviderSetupController controller,
  String providerId,
  String model,
) async {
  final outcome = await controller.setDefaultModel(providerId, model);
  if (outcome != DefaultSetOutcome.needsConfirmation) return outcome;
  final message = controller.confirmation?.message ?? '';
  if (!context.mounted) {
    controller.declineExpensiveModel();
    return DefaultSetOutcome.failed;
  }
  final confirmed = await confirmExpensiveModel(context, message: message);
  if (!confirmed) {
    controller.declineExpensiveModel();
    return DefaultSetOutcome.failed;
  }
  return controller.confirmExpensiveModel();
}

/// Opens the shared model picker and saves the pick as the default model.
/// With [only] the picker lists that provider's models alone (the step's
/// "Choose model"); otherwise every connected provider's.
Future<void> chooseDefaultModel(
  BuildContext context,
  ProviderSetupController controller, {
  ProviderEntry? only,
}) async {
  final catalog = controller.catalog;
  if (catalog == null) return;
  final l10n = context.l10n;
  final current = catalog.defaultModel.isEmpty
      ? null
      : ModelChoice(catalog.defaultProvider, catalog.defaultModel);
  final entries = only == null ? catalog.connected : [only];
  final options = modelOptionsOf(entries, current: current);
  if (options.providers.isEmpty) {
    // Hermes lists no models yet: read again instead of an empty picker.
    await controller.retryDefaultStep();
    return;
  }
  ModelChoice? pick;
  await showModelPicker(
    context,
    options: options,
    selected: current,
    withEffort: false,
    title: l10n.providersDefaultModelHeader,
    onChanged: (choice) => pick = choice,
  );
  final chosen = pick;
  if (chosen == null || !context.mounted) return;
  if (current != null && chosen.sameModel(current)) return;
  final outcome = await saveDefaultModel(
    context,
    controller,
    chosen.providerId,
    chosen.modelId,
  );
  if (!context.mounted) return;
  if (outcome == DefaultSetOutcome.refused ||
      outcome == DefaultSetOutcome.failed) {
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(l10n.providersStepFailedTitle)));
  }
}

/// The page of the default-model step, inside a connect sheet.
class ProviderStepPage extends StatelessWidget {
  const ProviderStepPage({
    super.key,
    required this.services,
    required this.providerId,
  });

  final ProviderFlowServices services;
  final String providerId;

  @override
  Widget build(BuildContext context) {
    final controller = services.controller;
    final step = controller.step;
    if (step == null) return const SizedBox.shrink();
    final entry = entryForSlug(controller.catalog, step.providerId);
    final data = defaultStepData(
      step,
      entry?.name ?? '',
      profile: services.profileLabel,
    );
    void close() => Navigator.of(context).maybePop();
    return SettingsScaffold(
      title: entry?.name ?? '',
      subtitle: services.profileLabel,
      cancel: true,
      macCancel: true,
      body: step_widget.DefaultModelStep(
        data: data,
        onStartChatting: () {
          controller.dismissStep();
          services.startChatting();
        },
        onChangeModel: () =>
            chooseDefaultModel(context, controller, only: entry),
        onChooseModel: () =>
            chooseDefaultModel(context, controller, only: entry),
        onUseModel: () {
          final model = step.model;
          if (model != null) {
            saveDefaultModel(context, controller, step.providerId, model);
          }
        },
        onKeepModel: () {
          controller.dismissStep();
          close();
        },
        onNotNow: () {
          controller.dismissStep();
          close();
        },
        onRetry: controller.retryDefaultStep,
      ),
    );
  }
}

/// A default-model step is open for this provider.
bool stepIsFor(ProviderSetupController controller, String providerId) {
  final step = controller.step;
  if (step == null) return false;
  if (step.providerId == providerId) return true;
  final entry = entryForSlug(controller.catalog, step.providerId);
  return entry != null && entry.id == providerId;
}

/// The default-model step on its own, for a step that begins while no connect
/// sheet is open (a sign-in approved while the person was elsewhere on the
/// screen). It closes itself when the step ends.
class ProviderStepSheet extends StatelessWidget {
  const ProviderStepSheet({super.key, required this.services});

  final ProviderFlowServices services;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: services.controller,
    builder: (context, _) {
      final step = services.controller.step;
      if (step == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) popIfCurrent(context);
        });
        return const SizedBox.shrink();
      }
      return ProviderSheetKeys(
        onSubmit: null,
        child: ProviderStepPage(
          services: services,
          providerId: step.providerId,
        ),
      );
    },
  );
}
