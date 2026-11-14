import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../widgets/settings_scaffold.dart';
import 'provider_flow.dart';
import 'provider_models.dart';
import 'provider_setup_controller.dart';
import 'provider_view_mapper.dart';
import 'widgets/endpoint_form.dart';
import 'widgets/provider_alerts.dart';
import 'widgets/provider_view_models.dart';

/// The custom endpoint form: new, or editing [entry]. It owns the four text
/// controllers. The endpoint's key is cleared when App Lock locks, after a
/// lost answer (the form does it) and when the sheet goes away; a saved key
/// is never shown, and an edit sends a key only when one was typed or the
/// person removed the saved one.
class ProviderEndpointSheet extends StatefulWidget {
  const ProviderEndpointSheet({super.key, required this.services, this.entry});

  final ProviderFlowServices services;

  /// The endpoint being edited; null for a new one.
  final ProviderEntry? entry;

  @override
  State<ProviderEndpointSheet> createState() => _ProviderEndpointSheetState();
}

class _ProviderEndpointSheetState extends State<ProviderEndpointSheet> {
  late final _name = TextEditingController(text: widget.entry?.name ?? '');
  late final _address = TextEditingController(
    text: widget.entry?.endpoint?.baseUrl ?? '',
  );
  final _key = TextEditingController();
  late final _model = TextEditingController(
    text: widget.entry?.endpoint?.model ?? '',
  );
  late final SecretFieldsLock _lock;

  late var _apiType = widget.entry == null
      ? ProviderApiType.automatic
      : apiTypeOfEntry(widget.entry!);
  var _apiTypeTouched = false;
  String? _selectedModel;
  var _useForNew = false;
  var _clearKey = false;
  var _closing = false;

  ProviderSetupController get _controller => widget.services.controller;
  bool get _editing => widget.entry != null;

  /// Saving made the endpoint the default (or the first provider), so the
  /// default-model step follows.
  bool get _stepOpen =>
      _controller.step?.providerId.startsWith('custom:') ?? false;

  @override
  void initState() {
    super.initState();
    _lock = SecretFieldsLock(widget.services.appLock, _key.clear);
  }

  @override
  void dispose() {
    _lock.dispose();
    _key.clear();
    for (final c in [_name, _address, _key, _model]) {
      c.dispose();
    }
    super.dispose();
  }

  void _close() {
    if (_closing || ModalRoute.of(context)?.isCurrent != true) return;
    _closing = true;
    Navigator.of(context).pop(ProviderSheetResult.closed);
  }

  void _closeWhenDone() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _closing) return;
      if (_controller.endpointForm.phase == EndpointFormPhase.saved &&
          !_stepOpen) {
        _close();
      }
    });
  }

  /// The model that goes with a save: the one picked from those the check
  /// found, else the one typed (or the endpoint's own on an edit).
  String get _modelToSave {
    final form = _controller.endpointForm;
    if (form.phase == EndpointFormPhase.checked && form.models.isNotEmpty) {
      return _selectedModel != null && form.models.contains(_selectedModel)
          ? _selectedModel!
          : form.models.first;
    }
    return _model.text.trim();
  }

  String? get _apiModeToSend =>
      _editing && !_apiTypeTouched ? null : apiModeOf(_apiType);

  bool get _offersUseForNew =>
      _controller.defaultModel.isNotEmpty &&
      (_controller.catalog?.connected.any((e) => e.isDefault) ?? false);

  Future<void> _check() => _controller.checkEndpoint(
    name: _name.text,
    address: _address.text,
    apiKey: _clearKey || _key.text.isEmpty ? null : _key.text,
    apiMode: _apiModeToSend,
    model: _model.text,
  );

  Future<void> _save({bool confirmedCleartext = false}) async {
    final typedKey = _key.text;
    final result = await _controller.saveEndpoint(
      id: widget.entry?.id,
      name: _name.text,
      address: _address.text,
      model: _modelToSave,
      apiKey: typedKey.isNotEmpty ? typedKey : (_clearKey ? '' : null),
      apiMode: _apiModeToSend,
      useForNewChats: _useForNew,
      confirmedClear: _clearKey && typedKey.isEmpty,
      confirmedCleartext: confirmedCleartext,
    );
    if (!mounted) return;
    if (result == EndpointSubmit.needsCleartextConfirmation) {
      final form = _controller.endpointForm;
      final typed = _address.text.trim();
      final address = form.checkedAddress == typed
          ? form.resolvedBaseUrl ?? typed
          : typed;
      final confirmed = await confirmCleartextKey(
        context,
        address: hostOfAddress(address),
      );
      // App Lock may have locked while the question was up and cleared the
      // key: saving then would drop it silently, so nothing is sent.
      final keyLost = typedKey.isNotEmpty && _key.text.isEmpty;
      if (confirmed && mounted && !keyLost) {
        await _save(confirmedCleartext: true);
      }
    }
    // The saved key's text must not outlive a save; a lost answer clears
    // it in the form.
    if (result == EndpointSubmit.saved) _key.clear();
  }

  Future<void> _removeSavedKey() async {
    final confirmed = await confirmRemoveEndpointKey(
      context,
      name: widget.entry?.name ?? _name.text,
    );
    if (confirmed && mounted) {
      setState(() => _clearKey = true);
      _controller.endpointEdited();
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = widget.services;
    return ListenableBuilder(
      listenable: Listenable.merge([
        _controller,
        _name,
        _address,
        _key,
        _model,
      ]),
      builder: (context, _) {
        if (_stepOpen) {
          if (_key.text.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _key.clear());
          }
          return ProviderSheetKeys(
            onSubmit: null,
            child: ProviderStepPage(
              services: services,
              providerId: _controller.step!.providerId,
            ),
          );
        }
        final form = _controller.endpointForm;
        if (form.phase == EndpointFormPhase.saved) _closeWhenDone();
        final l10n = context.l10n;
        final endpoint = widget.entry?.endpoint;
        final found =
            form.phase == EndpointFormPhase.checked &&
            form.models.isNotEmpty &&
            form.warning == null;
        final selected = found
            ? (_selectedModel != null && form.models.contains(_selectedModel)
                  ? _selectedModel
                  : form.models.first)
            : null;
        final data = endpointFormData(
          form,
          profile: services.profileLabel,
          editing: _editing,
          endpointName: widget.entry?.name ?? '',
          hasSavedKey: (endpoint?.hasApiKey ?? false) && !_clearKey,
          selectedModel: selected,
          apiType: _apiType,
          insecureKey: endpointSendsKeyUnencrypted(
            _address.text,
            hasKey: _key.text.isNotEmpty,
          ),
          offersUseForNew: _offersUseForNew,
          useForNew: _useForNew,
          currentModelName: _controller.defaultModel,
        );
        final canSave =
            !data.busy &&
            _name.text.trim().isNotEmpty &&
            _address.text.trim().isNotEmpty &&
            (data.selectedModel != null || _model.text.trim().isNotEmpty);
        return ProviderSheetKeys(
          onSubmit: canSave ? _save : null,
          child: SettingsScaffold(
            title: endpointFormTitle(l10n, data),
            subtitle: services.profileLabel,
            cancel: true,
            macCancel: true,
            formAction: endpointFormAction(
              l10n,
              data,
              canSave: canSave,
              onSave: _save,
            ),
            body: EndpointForm(
              data: data,
              nameController: _name,
              addressController: _address,
              keyController: _key,
              modelController: _model,
              onEdited: _controller.endpointEdited,
              onCheck: _check,
              onModelSelected: (model) =>
                  setState(() => _selectedModel = model),
              onApiTypeChanged: (type) => setState(() {
                _apiType = type;
                _apiTypeTouched = true;
              }),
              onUseForNewChanged: (value) => setState(() => _useForNew = value),
              onRemoveSavedKey: _removeSavedKey,
            ),
          ),
        );
      },
    );
  }
}
