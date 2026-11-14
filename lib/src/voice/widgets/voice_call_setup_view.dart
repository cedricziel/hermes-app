import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../calls/call_readiness.dart';
import 'voice_call_footer.dart';
import 'voice_consent_row.dart';

/// Plain readiness state and explicit actions, independent of call ownership.
///
/// The body scrolls, and so does the platform footer in it. Once every check
/// passed, the consent switch, Start call, "Use dictation instead" and the
/// one-line note under them stay pinned below the body, so they remain
/// reachable at the largest text size. The sentence about automatic sending
/// sits with the switch, and moves into the body once the text is large enough
/// that the pinned part would crowd it. Start call stays disabled until
/// [consented] is true. Without [onConsentChanged] there is no consent card and
/// Start call is enabled as soon as the checks pass.
class VoiceCallSetupView extends StatelessWidget {
  const VoiceCallSetupView({
    super.key,
    required this.readiness,
    required this.onClose,
    required this.onRetry,
    required this.onStart,
    this.onMicrophone,
    this.onDictation,
    this.onAskHermes,
    this.busy = false,
    this.microphoneDenied = false,
    this.error,
    this.consented = false,
    this.onConsentChanged,
    this.gptLiveNote = false,
    this.onUseDictation,
    this.footer = VoiceCallFooter.none,
  });
  final CallReadiness readiness;
  final VoidCallback onClose, onRetry, onStart;
  final VoidCallback? onMicrophone, onDictation, onAskHermes;
  final bool busy, microphoneDenied;
  final String? error;

  /// Whether the user allowed automatic sending for this call.
  final bool consented;
  final ValueChanged<bool>? onConsentChanged;

  /// Says the profile uses GPT-Live on the web, which this app does not.
  final bool gptLiveNote;

  /// "Use dictation instead": leaves the call for the chat's dictation.
  final VoidCallback? onUseDictation;
  final VoiceCallFooter footer;

  @override
  Widget build(BuildContext context) {
    final checking = readiness.isChecking;
    final consentMode = onConsentChanged != null;
    final canStart = !checking && !busy && (!consentMode || consented);
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, box) {
          final body = _Body(
            view: this,
            checking: checking,
            disabled: checking || busy,
          );
          final pinned = readiness.ready && !checking
              ? _Pinned(
                  view: this,
                  canStart: canStart,
                  consentMode: consentMode,
                )
              : null;
          Widget centred(Widget child) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: child,
            ),
          );
          if (!box.hasBoundedHeight) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
              child: centred(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [body, ?pinned],
                ),
              ),
            );
          }
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                  child: centred(body),
                ),
              ),
              if (pinned != null)
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: box.maxHeight * 0.65),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                      child: centred(pinned),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Above this text scale the consent sentence scrolls with the body instead of
/// standing over the pinned switch.
bool _sentenceInBody(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(1) >= 1.3;

/// "Use dictation instead" and the note about Start, which stand under Start
/// call and, at large text, scroll with the body instead.
List<Widget> _aftermath(BuildContext context, VoiceCallSetupView view) {
  final theme = Theme.of(context);
  final l10n = context.l10n;
  return [
    if (view.onUseDictation != null)
      TextButton(
        onPressed: view.busy ? null : view.onUseDictation,
        child: Text(l10n.voiceSetupDictationInstead),
      ),
    if (view.onConsentChanged != null) ...[
      const SizedBox(height: 8),
      Text(
        view.consented
            ? l10n.voiceSetupEndAnytime
            : l10n.voiceSetupConsentNeeded,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    ],
  ];
}

class _Body extends StatelessWidget {
  const _Body({
    required this.view,
    required this.checking,
    required this.disabled,
  });
  final VoiceCallSetupView view;
  final bool checking, disabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final readiness = view.readiness;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: view.onClose,
            child: Text(l10n.voiceSetupCancel),
          ),
        ),
        const SizedBox(height: 24),
        Icon(CupertinoIcons.phone, size: 44, color: theme.colorScheme.primary),
        const SizedBox(height: 20),
        Semantics(
          liveRegion: true,
          header: true,
          child: Text(
            checking
                ? l10n.voiceSetupChecking
                : readiness.ready
                ? l10n.voiceSetupReady
                : l10n.voiceSetupNotReady,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          checking
              ? l10n.voiceSetupCheckingBody
              : readiness.ready
              ? l10n.voiceSetupReadyBody
              : l10n.voiceSetupNotReadyBody,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 28),
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              for (var i = 0; i < readiness.checks.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 48),
                _CheckRow(check: readiness.checks[i]),
              ],
            ],
          ),
        ),
        if (view.gptLiveNote) ...[
          const SizedBox(height: 12),
          Text(
            l10n.voiceSetupGptLive,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (view.onConsentChanged != null &&
            readiness.ready &&
            _sentenceInBody(context)) ...[
          const SizedBox(height: 16),
          Text(l10n.voiceConsentSentence, style: theme.textTheme.bodyMedium),
        ],
        const SizedBox(height: 20),
        if (view.error != null) ...[
          Text(
            view.error!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (!checking) ...[
          if (readiness.checks.any(
            (c) => c.action == CallSetupAction.microphone,
          ))
            OutlinedButton(
              onPressed: disabled ? null : view.onMicrophone,
              child: Text(
                view.microphoneDenied
                    ? l10n.voiceSetupOpenSystemSettings
                    : l10n.voiceSetupAllowMicrophone,
              ),
            ),
          if (readiness.checks.any(
            (c) => c.action == CallSetupAction.dictation,
          ))
            OutlinedButton(
              onPressed: disabled ? null : view.onDictation,
              child: Text(l10n.voiceSetupOpenDictation),
            ),
          if (readiness.canAskHermes) ...[
            FilledButton(
              onPressed: disabled ? null : view.onAskHermes,
              child: Text(l10n.voiceSetupAskHermes),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.voiceSetupAskHermesNote,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (!readiness.ready)
            TextButton(
              onPressed: disabled ? null : view.onRetry,
              child: Text(l10n.voiceSetupCheckAgain),
            ),
        ],
        if (view.busy)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Center(child: CupertinoActivityIndicator()),
          ),
        if (readiness.ready && _sentenceInBody(context)) ...[
          const SizedBox(height: 8),
          ..._aftermath(context, view),
        ],
        if (readiness.ready && view.footer != VoiceCallFooter.none) ...[
          const SizedBox(height: 12),
          VoiceCallFooterText(view.footer),
        ],
      ],
    );
  }
}

/// The part that stays at the bottom once every check passed.
class _Pinned extends StatelessWidget {
  const _Pinned({
    required this.view,
    required this.canStart,
    required this.consentMode,
  });
  final VoiceCallSetupView view;
  final bool canStart, consentMode;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (consentMode) ...[
          VoiceConsentRow(
            showSentence: !_sentenceInBody(context),
            value: view.consented,
            onChanged: view.busy ? null : view.onConsentChanged,
          ),
          const SizedBox(height: 16),
        ],
        FilledButton(
          onPressed: canStart ? view.onStart : null,
          child: Text(l10n.voiceSetupStart),
        ),
        if (!_sentenceInBody(context)) ..._aftermath(context, view),
      ],
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.check});
  final CallCheck check;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ready = check.status == CallCheckStatus.ready;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (check.status == CallCheckStatus.checking)
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: CupertinoActivityIndicator(radius: 9),
            )
          else
            Icon(
              ready
                  ? CupertinoIcons.check_mark_circled
                  : CupertinoIcons.exclamationmark_circle,
              size: 20,
              color: ready
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(check.title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 3),
                Text(
                  check.detail,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
