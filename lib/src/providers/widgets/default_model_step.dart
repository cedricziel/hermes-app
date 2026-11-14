import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../widgets/app_banner.dart';
import '../../widgets/grouped_list.dart';
import 'provider_form_models.dart';
import 'provider_form_parts.dart';
import 'provider_row_actions.dart';

/// The step after a provider connected, from a plain [DefaultStepData]: an
/// icon tile, a title, the body in the muted colour, then the buttons stacked
/// full width (filled, outlined, text). A note above it says when the key
/// saved was not checked. It names models, so with App Lock on the screen
/// blanks it like any other.
///
/// - [DefaultStepView.ready]: "You're ready", Start chatting, Change model.
///   Also after a Nous sign-in that moved the default.
/// - [DefaultStepView.later]: "Use &lt;model&gt; for new chats?", Use, Keep, Choose
///   another.
/// - [DefaultStepView.choose]: nothing recommended; Choose model, Not now.
///   Nothing is saved and the provider's first model is never taken.
/// - [DefaultStepView.loading]: the models are not listed yet; a warning and
///   Retry. Nothing is saved until Retry finds them.
class DefaultModelStep extends StatelessWidget {
  const DefaultModelStep({
    super.key,
    required this.data,
    this.onStartChatting,
    this.onChangeModel,
    this.onUseModel,
    this.onKeepModel,
    this.onChooseModel,
    this.onNotNow,
    this.onRetry,
  });

  final DefaultStepData data;

  /// "Start chatting": closes everything, back to the chat or the list.
  final VoidCallback? onStartChatting;

  /// Opens the picker limited to this provider: "Change model", "Choose
  /// another model…" and "Choose model".
  final VoidCallback? onChangeModel;
  final VoidCallback? onUseModel;
  final VoidCallback? onKeepModel;
  final VoidCallback? onChooseModel;
  final VoidCallback? onNotNow;
  final VoidCallback? onRetry;

  Widget? _note(AppLocalizations l10n) => switch (data.note) {
    DefaultStepNote.none => null,
    DefaultStepNote.unchecked => AppBanner(
      tone: AppBannerTone.success,
      title: l10n.providersStepNoteSaved,
      detail: l10n.providersStepNoteUnchecked,
    ),
    DefaultStepNote.unreachable => AppBanner(
      tone: AppBannerTone.warning,
      title: l10n.providersStepNoteUnreachable(data.providerName),
    ),
  };

  AppIconSet get _icon => switch (data.view) {
    DefaultStepView.ready => AppIcons.checkCircle,
    DefaultStepView.loading => AppIcons.waiting,
    DefaultStepView.later || DefaultStepView.choose => AppIcons.tune,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final metrics = GroupedMetrics.of(context);
    final model = data.modelName ?? '';
    final current = data.currentModelName ?? '';
    final idle = !data.busy;
    final (title, body) = switch (data.view) {
      DefaultStepView.ready => (
        l10n.providersStepReadyTitle,
        l10n.providersStepReadyBody(data.profile, model, data.providerName),
      ),
      DefaultStepView.later => (
        l10n.providersStepLaterTitle(model),
        l10n.providersStepLaterBody(data.providerName, current),
      ),
      DefaultStepView.choose => (
        l10n.providersStepChooseTitle,
        l10n.providersStepChooseBody(data.providerName, data.profile),
      ),
      DefaultStepView.loading => (
        l10n.providersStepLoadingTitle(data.providerName),
        data.modelName == null
            ? null
            : l10n.providersStepLoadingModel(data.modelName!),
      ),
    };
    final note = _note(l10n);
    return GroupedListView(
      children: [
        if (note != null)
          Padding(padding: const EdgeInsets.only(top: 12), child: note),
        if (data.failed)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: AppBanner(
              tone: AppBannerTone.error,
              title: l10n.providersStepFailedTitle,
              detail: l10n.providersStepFailedDetail,
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            metrics.rowPadding,
            metrics.sectionGap + 8,
            metrics.rowPadding,
            0,
          ),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: ProviderIconTile(icon: _icon),
          ),
        ),
        ProviderHeading(title: title, body: body),
        if (data.view == DefaultStepView.loading)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: AppBanner(
              tone: AppBannerTone.warning,
              title: l10n.providersStepLoadingWarning,
              detail: l10n.providersStepLoadingDetail,
            ),
          ),
        ProviderActionStack(
          buttons: (full) => switch (data.view) {
            DefaultStepView.ready => [
              ProviderRowButton(
                label: l10n.providersStepStartChatting,
                filled: true,
                fullWidth: full,
                onPressed: idle ? onStartChatting : null,
              ),
              ProviderRowButton(
                label: l10n.providersStepChangeModel,
                outlined: true,
                fullWidth: full,
                onPressed: idle ? onChangeModel : null,
              ),
            ],
            DefaultStepView.later => [
              ProviderRowButton(
                label: l10n.providersStepUse(model),
                filled: true,
                fullWidth: full,
                onPressed: idle ? onUseModel : null,
              ),
              ProviderRowButton(
                label: l10n.providersStepKeep(current),
                outlined: true,
                fullWidth: full,
                onPressed: idle ? onKeepModel : null,
              ),
              ProviderRowButton(
                label: l10n.providersStepChooseAnother,
                fullWidth: full,
                onPressed: idle ? onChangeModel : null,
              ),
            ],
            DefaultStepView.choose => [
              ProviderRowButton(
                label: l10n.providersStepChoose,
                filled: true,
                fullWidth: full,
                onPressed: idle ? onChooseModel : null,
              ),
              ProviderRowButton(
                label: l10n.providersStepNotNow,
                fullWidth: full,
                onPressed: idle ? onNotNow : null,
              ),
            ],
            DefaultStepView.loading => [
              ProviderRowButton(
                label: l10n.providersStepRetry,
                filled: true,
                fullWidth: full,
                onPressed: idle ? onRetry : null,
              ),
              ProviderRowButton(
                label: l10n.providersStepNotNow,
                fullWidth: full,
                onPressed: idle ? onNotNow : null,
              ),
            ],
          },
        ),
      ],
    );
  }
}
