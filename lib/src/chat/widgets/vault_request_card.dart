import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../chat_models.dart';
import 'approval_card.dart' show kAnswerFailedMessage;
import 'input_card_frame.dart';

/// The agent asks for a credential through a masked prompt: a login to save
/// for the site it just visited, an external password manager's master
/// password, or a one-time code. The fields render as secure text fields and
/// the values travel only in the answer frame, never into the conversation.
/// "Not now" declines: Hermes carries on as if the user had declined there.
class VaultRequestCard extends StatefulWidget {
  const VaultRequestCard({
    super.key,
    required this.request,
    this.onAnswer,
    this.onSkip,
  });

  final VaultRequest request;

  /// Sends the value. Throwing means it did not go through. Without one the
  /// button is disabled.
  final Future<void> Function(String identifier, String password, String code)?
  onAnswer;

  /// Declines the request. Throwing means it did not go through. Without one
  /// the button is disabled.
  final Future<void> Function()? onSkip;

  @override
  State<VaultRequestCard> createState() => _VaultRequestCardState();
}

class _VaultRequestCardState extends State<VaultRequestCard> {
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  bool get _canSend => switch (widget.request.kind) {
    VaultKind.saveLogin =>
      _identifier.text.trim().isNotEmpty && _password.text.isNotEmpty,
    VaultKind.unlock => _password.text.isNotEmpty,
    VaultKind.code => _code.text.trim().isNotEmpty,
  };

  Future<void> _send() async {
    if (_busy || !_canSend) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onAnswer!(
        _identifier.text.trim(),
        _password.text,
        _code.text.trim(),
      );
      if (mounted) {
        // The values are on their way to Hermes; nothing of them may stay.
        _password.clear();
        _code.clear();
      }
    } on Object catch (_) {
      if (mounted) setState(() => _error = kAnswerFailedMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _skip() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSkip!();
    } on Object catch (_) {
      if (mounted) setState(() => _error = kAnswerFailedMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _title => switch (widget.request.kind) {
    VaultKind.saveLogin => 'Save a login for ${widget.request.site}?',
    VaultKind.unlock => 'Unlock $_managerName',
    VaultKind.code => 'One-time code for ${widget.request.site}',
  };

  String get _managerName {
    final name = widget.request.displayName;
    return name.isEmpty ? 'the password manager' : name;
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final enabled = request.status == InputRequestStatus.pending;
    final actionable = enabled && widget.onAnswer != null;
    return InputCardFrame(
      icon: AppIcons.lock,
      title: _title,
      child: switch (request.status) {
        InputRequestStatus.expired => const InputCardNote(
          'This request timed out',
        ),
        InputRequestStatus.answered => InputCardNote(switch (request.kind) {
          VaultKind.saveLogin =>
            request.provided
                ? 'Login saved for ${request.site}'
                : 'You declined to save a login',
          VaultKind.unlock =>
            request.provided
                ? '$_managerName unlocked'
                : 'You declined to unlock',
          VaultKind.code =>
            request.provided ? 'Code sent' : 'You skipped this request',
        }),
        InputRequestStatus.pending => AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (request.kind == VaultKind.saveLogin) ...[
                if (request.origin.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Hermes will fill this login the next time it meets '
                      '${request.origin}. The password is stored in your '
                      "vault, it never enters the conversation.",
                    ),
                  ),
                TextField(
                  controller: _identifier,
                  autofillHints: const [AutofillHints.username],
                  textInputAction: TextInputAction.next,
                  enabled: actionable,
                  decoration: const InputDecoration(
                    labelText: 'Username or email',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
              ],
              if (request.kind == VaultKind.code) ...[
                if (request.hint.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(request.hint),
                  ),
                TextField(
                  controller: _code,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  textInputAction: TextInputAction.done,
                  keyboardType: TextInputType.visiblePassword,
                  enabled: actionable,
                  onSubmitted: (_) => _send(),
                  decoration: const InputDecoration(labelText: 'Code'),
                  onChanged: (_) => setState(() {}),
                ),
              ] else
                TextField(
                  controller: _password,
                  autofillHints: switch (request.kind) {
                    VaultKind.saveLogin => const [AutofillHints.password],
                    _ => const [],
                  },
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  enabled: actionable,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    labelText: switch (request.kind) {
                      VaultKind.saveLogin => 'Password',
                      _ => 'Master password',
                    },
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: !actionable || !_canSend || _busy ? null : _send,
                    child: Text(switch (request.kind) {
                      VaultKind.saveLogin => 'Save login',
                      VaultKind.unlock => 'Unlock',
                      VaultKind.code => 'Send code',
                    }),
                  ),
                  TextButton(
                    onPressed: !enabled || widget.onSkip == null || _busy
                        ? null
                        : _skip,
                    child: const Text('Not now'),
                  ),
                ],
              ),
              if (_error != null) InputCardNote(_error!, error: true),
            ],
          ),
        ),
      },
    );
  }
}
