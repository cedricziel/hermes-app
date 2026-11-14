import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../theme/app_icons.dart';
import '../theme/platform_chrome.dart';
import 'grouped_form.dart';
import 'named_icon_button.dart';

/// A typed key, token or password in a grouped form.
///
/// The rule for secret fields is in `docs/architecture/settings-screens.md`
/// ("Secret fields"). The value is hidden until the user presses Show key.
/// Under the field a muted line says how many characters were typed; the
/// count is read from [controller] each time and never kept.
///
/// A shown value is hidden again when the app leaves `resumed`, when [busy]
/// turns true (a check or save started), when [hideSignal] changes (the
/// screen passes a counter it raises after a failed save) and when the row
/// goes away. Hiding never touches the text; the screen clears [controller]
/// itself when App Lock locks, the form closes or an answer to a save is lost.
/// The shown state is neither persisted nor restored, so there is no
/// `restorationId`, and nothing here logs the typed value.
class SecretFieldRow extends StatefulWidget {
  const SecretFieldRow({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.enabled = true,
    this.busy = false,
    this.hideSignal,
    this.errorText,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.initiallyShown = false,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;

  /// False while the form cannot be edited.
  final bool enabled;

  /// True while a check or save runs; a shown value is hidden when it starts.
  final bool busy;

  /// Hides a shown value whenever it changes. Raise it after a failed save.
  final Object? hideSignal;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;

  /// Starts with the value shown. Only the catalog sets it, to draw that
  /// state; a screen leaves it false, since a shown value is never restored.
  final bool initiallyShown;

  @override
  State<SecretFieldRow> createState() => _SecretFieldRowState();
}

class _SecretFieldRowState extends State<SecretFieldRow>
    with WidgetsBindingObserver {
  late var _shown = widget.initiallyShown;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(SecretFieldRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_shown &&
        ((widget.busy && !oldWidget.busy) ||
            widget.hideSignal != oldWidget.hideSignal)) {
      _shown = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _shown) {
      setState(() => _shown = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Widget _toggle(BuildContext context) {
    final l10n = context.l10n;
    final label = _shown ? l10n.widgetsSecretHide : l10n.widgetsSecretShow;
    void toggle() => setState(() => _shown = !_shown);
    final chrome = platformChromeOf(context);
    if (chrome == PlatformChrome.macos) {
      return Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: TextButton(
          onPressed: widget.enabled ? toggle : null,
          child: Text(
            _shown ? l10n.widgetsSecretHideShort : l10n.widgetsSecretShowShort,
          ),
        ),
      );
    }
    final side = chrome == PlatformChrome.ios ? kAppleMinTapTarget : 48.0;
    return NamedIconButton(
      label: label,
      icon: _shown ? AppIcons.eyeOff : AppIcons.eye,
      onPressed: widget.enabled ? toggle : null,
      constraints: BoxConstraints(minWidth: side, minHeight: side),
    );
  }

  @override
  Widget build(BuildContext context) {
    final android = Theme.of(context).platform == TargetPlatform.android;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GroupedTextFieldRow(
          label: widget.label,
          hint: widget.hint,
          controller: widget.controller,
          enabled: widget.enabled,
          obscureText: !_shown,
          maxLines: 1,
          autocorrect: false,
          enableSuggestions: false,
          enableIMEPersonalizedLearning: false,
          autofillHints: const <String>[],
          smartDashesType: SmartDashesType.disabled,
          smartQuotesType: SmartQuotesType.disabled,
          keyboardType: android ? TextInputType.visiblePassword : null,
          textCapitalization: TextCapitalization.none,
          textInputAction: widget.textInputAction,
          errorText: widget.errorText,
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
          trailing: _toggle(context),
        ),
        ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            final count = widget.controller.text.characters.length;
            if (count == 0) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Semantics(
                liveRegion: true,
                child: GroupedFooter(
                  context.l10n.widgetsSecretCharactersEntered(count),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
