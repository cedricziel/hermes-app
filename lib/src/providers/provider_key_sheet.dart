import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../widgets/settings_scaffold.dart';
import 'provider_flow.dart';
import 'provider_links.dart';
import 'provider_setup_controller.dart';
import 'provider_view_mapper.dart';
import 'widgets/api_key_form.dart';

/// The form that takes an API key for [providerId], and the default-model
/// step it ends in. It owns the key's text controller: the key is cleared
/// when App Lock locks, once it is saved and when the sheet goes away, and
/// is never persisted or restored. Closing the sheet is the caller's cue to
/// call `closeKeyForm`.
class ProviderKeySheet extends StatefulWidget {
  const ProviderKeySheet({
    super.key,
    required this.services,
    required this.providerId,
  });

  final ProviderFlowServices services;
  final String providerId;

  @override
  State<ProviderKeySheet> createState() => _ProviderKeySheetState();
}

class _ProviderKeySheetState extends State<ProviderKeySheet> {
  final _key = TextEditingController();
  late final SecretFieldsLock _lock;
  var _closing = false;

  ProviderSetupController get _controller => widget.services.controller;

  @override
  void initState() {
    super.initState();
    _lock = SecretFieldsLock(widget.services.appLock, _key.clear);
  }

  @override
  void dispose() {
    _lock.dispose();
    _key.clear();
    _key.dispose();
    super.dispose();
  }

  void _close([ProviderSheetResult result = ProviderSheetResult.closed]) {
    if (_closing) return;
    _closing = true;
    Navigator.of(context).pop(result);
  }

  /// A replacement saved: nothing follows, so the sheet closes once the
  /// frame is done (a first key's step is set in the same turn).
  void _closeWhenDone() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _closing) return;
      final form = _controller.keyForm;
      if (form?.phase == KeyFormPhase.saved &&
          !stepIsFor(_controller, widget.providerId)) {
        _key.clear();
        _close();
      }
    });
  }

  void _submit() {
    _controller.pressReturn(_key.text);
  }

  @override
  Widget build(BuildContext context) {
    final services = widget.services;
    return ListenableBuilder(
      listenable: Listenable.merge([_controller, _key]),
      builder: (context, _) {
        if (stepIsFor(_controller, widget.providerId)) {
          if (_key.text.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _key.clear());
          }
          return ProviderSheetKeys(
            onSubmit: null,
            child: ProviderStepPage(
              services: services,
              providerId: widget.providerId,
            ),
          );
        }
        final form = _controller.keyForm;
        if (form == null || form.phase == KeyFormPhase.saved) {
          if (form != null) _closeWhenDone();
          return const SizedBox.shrink();
        }
        final l10n = context.l10n;
        final entry = _controller.catalog?.byId(widget.providerId);
        final link = openableLink(entry?.keyUrl);
        final data = apiKeyFormData(
          form,
          entry,
          profile: services.profileLabel,
          keyLinkOpenable: link != null,
        );
        return ProviderSheetKeys(
          onSubmit: _submit,
          child: SettingsScaffold(
            title: apiKeyFormTitle(l10n, data),
            subtitle: services.profileLabel,
            cancel: true,
            formAction: apiKeyFormAction(
              l10n,
              data,
              hasText: _key.text.isNotEmpty,
              onSave: () => _controller.submitKey(_key.text),
            ),
            body: ApiKeyForm(
              data: data,
              controller: _key,
              focusRequest: _controller.keyFocusRequests,
              onChanged: (_) => _controller.keyEdited(),
              onSave: _controller.submitKey,
              onSaveAnyway: _controller.saveKeyAnyway,
              onTryAgain: _controller.submitKey,
              onEditKey: _controller.editKey,
              onOpenKeyLink: link == null
                  ? null
                  : () => services.openLink(link),
              onUseAccount: () => _close(ProviderSheetResult.useAccount),
            ),
          ),
        );
      },
    );
  }
}
