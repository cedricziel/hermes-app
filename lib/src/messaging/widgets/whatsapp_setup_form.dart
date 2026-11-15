import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../theme/platform_chrome.dart';
import '../../widgets/app_banner.dart';
import '../../widgets/grouped_choice_row.dart';
import '../../widgets/grouped_form.dart';
import '../../widgets/grouped_list.dart';
import '../whatsapp/whatsapp_pairing.dart';
import 'pairing_buttons.dart';
import 'pairing_end.dart';

/// Why the allowed numbers cannot be sent.
enum WhatsAppNumbersIssue {
  /// Something that is not a phone number.
  notPhoneNumber,

  /// `*` or a WhatsApp address: everyone-access is a server setting.
  everyone,
}

/// What went wrong with the last start.
enum WhatsAppStartProblem {
  /// The server refused (400 or 422); its text is the detail.
  refused,

  /// Nothing was sent: no connection could be made.
  offline,

  /// The request went out and got no answer. Starting again replaces it.
  lostAnswer,
}

/// The form of the WhatsApp link: the mode, the allowed numbers and Start.
///
/// Mode is two choice rows, Bot and Self-chat, each with a short subtitle; the
/// two full sentences are the section's footer. The numbers are one
/// two-line field, labelled by its section header (an Apple multi-line row
/// shows only its value or hint), with the phone keyboard, autocorrect and
/// suggestions off. A blank list is valid: the server keeps what it has.
/// Nothing is sent by this widget. Start is the screen's one filled button;
/// after a lost start it gives way to the banner's "Start again". The form
/// keeps its values in every state.
class WhatsAppSetupForm extends StatelessWidget {
  const WhatsAppSetupForm({
    super.key,
    required this.mode,
    required this.onModeChanged,
    required this.numbers,
    this.numbersIssue,
    this.onNumbersChanged,
    this.problem,
    this.serverText,
    this.starting = false,
    required this.onStart,
    this.onStartAgain,
    this.handset = true,
  });

  final WhatsAppMode mode;
  final ValueChanged<WhatsAppMode> onModeChanged;

  /// The field's text; the caller owns it, so a Start again keeps the values.
  final TextEditingController numbers;
  final WhatsAppNumbersIssue? numbersIssue;
  final ValueChanged<String>? onNumbersChanged;
  final WhatsAppStartProblem? problem;

  /// The server's text for [WhatsAppStartProblem.refused]; display only.
  final String? serverText;

  /// The start request is out: Start shows "Starting..." and the form is
  /// locked.
  final bool starting;
  final VoidCallback? onStart;
  final VoidCallback? onStartAgain;
  final bool handset;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final metrics = GroupedMetrics.of(context);
    final scheme = Theme.of(context).colorScheme;
    final muted = context.hermesColors.subtleText;
    final apple = platformChromeOf(context).isApple;
    final issue = numbersIssue;
    final lost = problem == WhatsAppStartProblem.lostAnswer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (problem != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _problemBanner(context, problem!),
          ),
        RadioGroup<WhatsAppMode>(
          groupValue: mode,
          onChanged: (value) {
            if (value != null && !starting) onModeChanged(value);
          },
          child: GroupedSection(
            header: l10n.messagingWhatsappModeHeader,
            footer: l10n.messagingWhatsappModeFooter,
            dividerIndent: GroupedChoiceRow.dividerIndent(context),
            children: [
              GroupedChoiceRow<WhatsAppMode>(
                value: WhatsAppMode.bot,
                title: l10n.messagingWhatsappModeBot,
                subtitle: l10n.messagingWhatsappModeBotSubtitle,
                subtitleMaxLines: null,
                enabled: !starting,
              ),
              GroupedChoiceRow<WhatsAppMode>(
                value: WhatsAppMode.selfChat,
                title: l10n.messagingWhatsappModeSelfChat,
                subtitle: l10n.messagingWhatsappModeSelfChatSubtitle,
                subtitleMaxLines: null,
                enabled: !starting,
              ),
            ],
          ),
        ),
        GroupedSection(
          header: l10n.messagingWhatsappNumbersHeader,
          footer: l10n.messagingWhatsappNumbersFooter,
          children: [
            GroupedTextFieldRow(
              key: const Key('whatsapp-numbers'),
              label: l10n.messagingWhatsappNumbersHeader,
              hint: l10n.messagingWhatsappNumbersHint,
              controller: numbers,
              enabled: !starting,
              minLines: 2,
              maxLines: 2,
              // The iOS phone pad has no comma; the numbers are separated by
              // commas, so Apple platforms get numbers and punctuation.
              keyboardType: apple
                  ? const TextInputType.numberWithOptions(signed: true)
                  : TextInputType.phone,
              autocorrect: false,
              enableSuggestions: false,
              enableIMEPersonalizedLearning: false,
              onChanged: onNumbersChanged,
            ),
            if (issue != null)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  metrics.rowPadding,
                  0,
                  metrics.rowPadding,
                  10,
                ),
                child: GroupedStatusLine(
                  icon: AppIcons.error,
                  color: scheme.error,
                  size: metrics.subtitleSize,
                  scaleIcon: true,
                  liveRegion: true,
                  text: switch (issue) {
                    WhatsAppNumbersIssue.notPhoneNumber =>
                      l10n.messagingWhatsappNumbersInvalid,
                    WhatsAppNumbersIssue.everyone =>
                      l10n.messagingWhatsappNumbersEveryone,
                  },
                ),
              ),
          ],
        ),
        if (!lost) ...[
          const SizedBox(height: 20),
          PairingActions(
            handset: handset,
            children: [
              PairingButton.filled(
                label: starting
                    ? l10n.messagingWhatsappStarting
                    : l10n.messagingWhatsappStart,
                busy: starting,
                onPressed: onStart,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              l10n.messagingWhatsappStartNote,
              style: TextStyle(fontSize: metrics.footerSize, color: muted),
            ),
          ),
        ],
      ],
    );
  }

  Widget _problemBanner(BuildContext context, WhatsAppStartProblem problem) {
    final l10n = context.l10n;
    return switch (problem) {
      WhatsAppStartProblem.refused => AppBanner(
        tone: AppBannerTone.error,
        title: l10n.messagingWhatsappStartRefusedTitle,
        detail: serverText == null ? '' : whatsAppSafeServerText(serverText!),
      ),
      WhatsAppStartProblem.offline => AppBanner(
        tone: AppBannerTone.warning,
        title: l10n.messagingWhatsappOfflineTitle,
        detail: l10n.messagingWhatsappStartOfflineDetail,
      ),
      WhatsAppStartProblem.lostAnswer => AppBanner(
        tone: AppBannerTone.warning,
        title: l10n.messagingWhatsappStartLostTitle,
        detail: l10n.messagingWhatsappStartLostDetail,
        action: PairingButton.filled(
          label: l10n.messagingWhatsappStartAgain,
          onPressed: onStartAgain,
        ),
      ),
    };
  }
}
