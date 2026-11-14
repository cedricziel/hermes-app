import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../theme/platform_chrome.dart';
import '../../widgets/grouped_form.dart';
import '../../widgets/grouped_list.dart';
import '../../widgets/state_message.dart';
import 'provider_form_models.dart';
import 'provider_form_parts.dart';
import 'provider_row_actions.dart';

/// A device code spelled out for a screen reader: each character on its own,
/// the groups the provider gave it apart ("W D J B, M J H T").
String spokenSignInCode(String code) => [
  for (final group in code.split(RegExp(r'[\s-]+')))
    if (group.isNotEmpty) group.split('').join(' '),
].join(', ');

/// The step of an account sign-in, from a plain [SignInCodeData]: while it
/// waits, "Open &lt;provider&gt;" (the one filled, full-width button) and the code
/// in a bordered card with an outlined Copy code under it, then a status line
/// and the code's lifetime; when it ended or could not start, one message
/// with one filled button.
///
/// The code is shown and copyable only: nothing here logs it, and the screen
/// hands a new [SignInCodeData] without it once the sign-in ended. Cancel is
/// the bar's leading button.
class SignInCodeView extends StatefulWidget {
  const SignInCodeView({
    super.key,
    required this.data,
    this.initiallyCopied = false,
    this.onOpen,
    this.onCopied,
    this.onStartAgain,
    this.onCheckAgain,
  });

  final SignInCodeData data;

  /// Only the catalog sets it, to draw the button's "Copied" moment.
  final bool initiallyCopied;
  final VoidCallback? onOpen;
  final VoidCallback? onCopied;

  /// Declined, expired, failed or a start that got no answer.
  final VoidCallback? onStartAgain;

  /// A start Hermes refused: reads the providers again.
  final VoidCallback? onCheckAgain;

  @override
  State<SignInCodeView> createState() => _SignInCodeViewState();
}

class _SignInCodeViewState extends State<SignInCodeView> {
  Timer? _reset;
  late var _copied = widget.initiallyCopied;

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  Future<void> _copy(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    setState(() => _copied = true);
    _reset?.cancel();
    _reset = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
    widget.onCopied?.call();
  }

  Widget _step(BuildContext context, String text) {
    final metrics = GroupedMetrics.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        metrics.rowPadding,
        metrics.sectionGap,
        metrics.rowPadding,
        0,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: metrics.titleSize,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _codeCard(BuildContext context, AppLocalizations l10n, String code) {
    final scheme = Theme.of(context).colorScheme;
    final metrics = GroupedMetrics.of(context);
    // The code breaks only between its groups, so each stays whole.
    final groups = code
        .split(RegExp(r'(?<=[-\s])'))
        .where((g) => g.trim().isNotEmpty)
        .toList();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        metrics.rowPadding,
        12,
        metrics.rowPadding,
        0,
      ),
      child: Semantics(
        container: true,
        liveRegion: true,
        label: l10n.providersSignInCodeSemantics(spokenSignInCode(code)),
        excludeSemantics: true,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border.all(color: scheme.outline),
            borderRadius: BorderRadius.circular(metrics.radius),
          ),
          child: Wrap(
            alignment: WrapAlignment.center,
            runSpacing: 4,
            children: [
              for (final group in groups)
                // A group that is wider than the card shrinks to fit, so it
                // is never split.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SelectableText(
                    group,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 34,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _waiting(BuildContext context, AppLocalizations l10n) {
    final data = widget.data;
    final metrics = GroupedMetrics.of(context);
    final code = data.code;
    final mac = platformChromeOf(context) == PlatformChrome.macos;
    final minutes = data.expiresInMinutes;
    return GroupedListView(
      children: [
        _step(context, l10n.providersSignInStepOpen(data.providerName)),
        if (data.canOpen)
          ProviderActionStack(
            buttons: (full) => [
              ProviderRowButton(
                label: l10n.providersSignInOpen(data.providerName),
                filled: true,
                fullWidth: full,
                onPressed: widget.onOpen,
              ),
            ],
          ),
        if (code != null) ...[
          _step(
            context,
            data.codeInLink
                ? l10n.providersSignInCodeMatch
                : l10n.providersSignInStepCode,
          ),
          _codeCard(context, l10n, code),
          Padding(
            padding: EdgeInsets.fromLTRB(
              metrics.rowPadding,
              12,
              metrics.rowPadding,
              0,
            ),
            child: Align(
              alignment: mac ? Alignment.center : Alignment.topCenter,
              child: ProviderRowButton(
                label: _copied
                    ? l10n.providersSignInCopied
                    : l10n.providersSignInCopyCode,
                semanticsLabel: _copied
                    ? l10n.providersSignInCopiedAnnouncement
                    : l10n.providersSignInCopyCode,
                outlined: true,
                fullWidth: !mac,
                liveRegion: _copied,
                onPressed: () => _copy(code),
              ),
            ),
          ),
        ],
        ProviderStatusLine(
          data.offline
              ? l10n.providersSignInOffline
              : l10n.providersSignInWaiting,
          warning: data.offline,
        ),
        if (minutes != null)
          GroupedFooter(l10n.providersSignInExpires(minutes)),
        GroupedFooter(l10n.providersSignInProfileNote(data.profile)),
      ],
    );
  }

  Widget _message(
    AppLocalizations l10n, {
    required AppIconSet icon,
    required String title,
    String? detail,
    required String action,
    required VoidCallback? onPressed,
  }) => GroupedListView(
    children: [
      StateMessage(
        icon: icon,
        title: title,
        detail: detail,
        action: ProviderRowButton(
          label: action,
          filled: true,
          onPressed: onPressed,
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final data = widget.data;
    return switch (data.phase) {
      SignInStepPhase.waiting => _waiting(context, l10n),
      SignInStepPhase.declined => _message(
        l10n,
        icon: AppIcons.error,
        title: l10n.providersSignInDeclined,
        action: l10n.providersSignInStartAgain,
        onPressed: widget.onStartAgain,
      ),
      SignInStepPhase.expired => _message(
        l10n,
        icon: AppIcons.warning,
        title: l10n.providersSignInExpired,
        action: l10n.providersSignInStartAgain,
        onPressed: widget.onStartAgain,
      ),
      SignInStepPhase.failed => _message(
        l10n,
        icon: AppIcons.error,
        title: l10n.providersSignInFailed,
        detail: data.message,
        action: l10n.providersSignInStartAgain,
        onPressed: widget.onStartAgain,
      ),
      SignInStepPhase.startRefused => _message(
        l10n,
        icon: AppIcons.info,
        title: data.message ?? l10n.providersSignInStartRefusedFallback,
        action: l10n.providersCheckAgain,
        onPressed: widget.onCheckAgain,
      ),
      SignInStepPhase.startFailed => _message(
        l10n,
        icon: AppIcons.warning,
        title: l10n.providersSignInStartFailedTitle,
        detail: l10n.providersSignInStartFailedDetail,
        action: l10n.providersTryAgain,
        onPressed: widget.onStartAgain,
      ),
    };
  }
}
