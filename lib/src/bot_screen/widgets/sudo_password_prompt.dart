import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoTextField;
import 'package:flutter/material.dart';

import '../../telemetry/breadcrumbs.dart';
import '../../theme/platform_chrome.dart';
import '../../widgets/adaptive_dialog.dart';
import '../../widgets/dialog_presentation.dart';
import '../../widgets/route_dismissal.dart';

/// The question Hermes asks before it installs the desktop: the sudo password
/// of the server's user.
///
/// A plain widget over [host] and two callbacks, drawn as the platform's alert
/// (a Cupertino alert on iOS and macOS, a Material one elsewhere). The field
/// is obscured and tells the keyboard and the system to remember nothing:
/// autocorrect, suggestions, keyboard learning and autofill are off. Install
/// hands the typed password to [onInstall] once, clearing the field as it
/// does; Cancel only calls [onCancel]. The password is never kept
/// here, shown again or recorded.
class SudoPasswordPrompt extends StatefulWidget {
  const SudoPasswordPrompt({
    super.key,
    required this.host,
    required this.onInstall,
    required this.onCancel,
    this.controller,
  });

  /// The Hermes host the password is for.
  final String host;
  final ValueChanged<String> onInstall;
  final VoidCallback onCancel;

  /// Holds the typed text, when the caller owns it (a catalog use case shows
  /// a filled field). Without one the prompt makes its own.
  final TextEditingController? controller;

  @override
  State<SudoPasswordPrompt> createState() => _SudoPasswordPromptState();
}

class _SudoPasswordPromptState extends State<SudoPasswordPrompt> {
  TextEditingController? _own;
  var _answered = false;

  TextEditingController get _controller =>
      widget.controller ?? (_own ??= TextEditingController());

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  void _install() {
    if (_answered || _controller.text.isEmpty) return;
    _answered = true;
    final password = _controller.text;
    _controller.clear();
    widget.onInstall(password);
  }

  void _cancel() {
    if (_answered) return;
    _answered = true;
    _controller.clear();
    widget.onCancel();
  }

  @override
  Widget build(BuildContext context) {
    final apple = platformChromeOf(context).isApple;
    return AppAlertDialog(
      title: const Text('Sudo password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hermes on ${widget.host} needs the password of its user to '
            'install the desktop. It goes to your server once and is not '
            'stored.',
          ),
          const SizedBox(height: 12),
          apple ? _appleField() : _materialField(),
        ],
      ),
      actions: [
        AppDialogAction(onPressed: _cancel, child: const Text('Cancel')),
        ValueListenableBuilder(
          valueListenable: _controller,
          builder: (context, value, _) => AppDialogAction(
            isDefault: true,
            onPressed: value.text.isEmpty || _answered ? null : _install,
            child: const Text('Install'),
          ),
        ),
      ],
    );
  }

  Widget _materialField() => TextField(
    controller: _controller,
    autofocus: true,
    obscureText: true,
    autocorrect: false,
    enableSuggestions: false,
    enableIMEPersonalizedLearning: false,
    autofillHints: null,
    keyboardType: TextInputType.visiblePassword,
    smartDashesType: SmartDashesType.disabled,
    smartQuotesType: SmartQuotesType.disabled,
    textInputAction: TextInputAction.done,
    onSubmitted: (_) => _install(),
    decoration: const InputDecoration(labelText: 'Password'),
  );

  Widget _appleField() => CupertinoTextField(
    controller: _controller,
    autofocus: true,
    obscureText: true,
    autocorrect: false,
    enableSuggestions: false,
    enableIMEPersonalizedLearning: false,
    autofillHints: null,
    keyboardType: TextInputType.visiblePassword,
    smartDashesType: SmartDashesType.disabled,
    smartQuotesType: SmartQuotesType.disabled,
    textInputAction: TextInputAction.done,
    onSubmitted: (_) => _install(),
    placeholder: 'Password',
  );
}

/// Asks for the sudo password of [host] over whatever is on screen.
///
/// Answers the typed password, or null when the user cancels or dismisses the
/// question. The question closes by itself, answering null, when [ended]
/// completes: the install is over and nobody is waiting. Records
/// `bot_screen.install.password` (`outcome`: answered or cancelled) in
/// [breadcrumbs], with no text.
Future<String?> showSudoPasswordPrompt(
  BuildContext context, {
  required String host,
  required Future<void> ended,
  Breadcrumbs breadcrumbs = Breadcrumbs.none,
}) async {
  var over = false;
  final password = await showAppDialog<String>(
    context: context,
    builder: (context) => _CloseWhen(
      ended: ended,
      onEnded: () => over = true,
      child: SudoPasswordPrompt(
        host: host,
        onInstall: (password) => Navigator.pop(context, password),
        onCancel: () => Navigator.pop(context),
      ),
    ),
  );
  if (!over) {
    breadcrumbs('bot_screen.install.password', {
      'outcome': password == null ? 'cancelled' : 'answered',
    });
  }
  return password;
}

/// Removes the route it sits in once [ended] completes, whether that is
/// before or after the route was built.
class _CloseWhen extends StatefulWidget {
  const _CloseWhen({
    required this.ended,
    required this.onEnded,
    required this.child,
  });

  final Future<void> ended;
  final VoidCallback onEnded;
  final Widget child;

  @override
  State<_CloseWhen> createState() => _CloseWhenState();
}

class _CloseWhenState extends State<_CloseWhen> {
  @override
  void initState() {
    super.initState();
    unawaited(
      widget.ended.then((_) {
        if (!mounted) return;
        widget.onEnded();
        dismissRoute(context);
      }),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
