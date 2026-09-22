import 'package:flutter/material.dart';

import '../model_provider_option.dart';
import 'model_menu_chip.dart';

/// The composer's model picker: a chip that opens a searchable dropdown of
/// the ready providers' models, mirroring the dashboard's own model picker.
/// Only [ModelProviderOption.ready] providers are listed — a chat cannot
/// pick a model the server has no credentials for.
class ModelMenuButton extends StatefulWidget {
  const ModelMenuButton({
    super.key,
    required this.providers,
    required this.selectedProviderId,
    required this.selectedModelId,
    required this.onModelSelected,
    this.onRefresh,
    this.onEditModels,
    this.initiallyOpen = false,
  });

  final List<ModelProviderOption> providers;
  final String selectedProviderId;
  final String selectedModelId;
  final void Function(String providerId, String modelId) onModelSelected;
  final VoidCallback? onRefresh;
  final VoidCallback? onEditModels;

  /// Opens the dropdown as soon as it is built, for the catalog: previewing
  /// the closed chip alone would miss the point of the widget.
  final bool initiallyOpen;

  @override
  State<ModelMenuButton> createState() => _ModelMenuButtonState();
}

class _ModelMenuButtonState extends State<ModelMenuButton> {
  final _controller = MenuController();

  @override
  void initState() {
    super.initState();
    if (widget.initiallyOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.open();
      });
    }
  }

  String get _label {
    for (final provider in widget.providers) {
      if (provider.id != widget.selectedProviderId) continue;
      for (final model in provider.models) {
        if (model.id == widget.selectedModelId) return model.displayLabel;
      }
    }
    return 'Choose a model';
  }

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      controller: _controller,
      style: const MenuStyle(padding: WidgetStatePropertyAll(EdgeInsets.zero)),
      menuChildren: [
        _ModelMenuContent(
          providers: widget.providers,
          selectedProviderId: widget.selectedProviderId,
          selectedModelId: widget.selectedModelId,
          onSelected: (providerId, modelId) {
            _controller.close();
            widget.onModelSelected(providerId, modelId);
          },
          onRefresh: widget.onRefresh == null
              ? null
              : () {
                  _controller.close();
                  widget.onRefresh!();
                },
          onEditModels: widget.onEditModels == null
              ? null
              : () {
                  _controller.close();
                  widget.onEditModels!();
                },
        ),
      ],
      builder: (context, controller, child) => ModelMenuChip(
        label: _label,
        onTap: () => controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}

class _ModelMenuContent extends StatefulWidget {
  const _ModelMenuContent({
    required this.providers,
    required this.selectedProviderId,
    required this.selectedModelId,
    required this.onSelected,
    this.onRefresh,
    this.onEditModels,
  });

  final List<ModelProviderOption> providers;
  final String selectedProviderId;
  final String selectedModelId;
  final void Function(String providerId, String modelId) onSelected;
  final VoidCallback? onRefresh;
  final VoidCallback? onEditModels;

  @override
  State<_ModelMenuContent> createState() => _ModelMenuContentState();
}

class _ModelMenuContentState extends State<_ModelMenuContent> {
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final rows = [
      for (final provider in widget.providers)
        if (provider.ready)
          for (final model in provider.models)
            if (_matches(model)) (provider: provider, model: model),
    ];
    return SizedBox(
      width: 280,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Search models',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: rows.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('No models match', textAlign: TextAlign.center),
                  )
                : SingleChildScrollView(
                    primary: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final row in rows)
                          ListTile(
                            key: Key(
                              'model-option-${row.provider.id}-${row.model.id}',
                            ),
                            dense: true,
                            title: Text(row.model.displayLabel),
                            trailing:
                                row.provider.id == widget.selectedProviderId &&
                                    row.model.id == widget.selectedModelId
                                ? const Icon(Icons.check, size: 18)
                                : null,
                            onTap: () => widget.onSelected(
                              row.provider.id,
                              row.model.id,
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
          if (widget.onRefresh != null || widget.onEditModels != null) ...[
            const Divider(height: 1),
            if (widget.onRefresh != null)
              ListTile(
                dense: true,
                leading: const Icon(Icons.refresh, size: 18),
                title: const Text('Refresh models'),
                onTap: widget.onRefresh,
              ),
            if (widget.onEditModels != null)
              ListTile(
                key: const Key('model-menu-edit'),
                dense: true,
                leading: const Icon(Icons.settings_outlined, size: 18),
                title: const Text('Edit models…'),
                onTap: widget.onEditModels,
              ),
          ],
        ],
      ),
    );
  }

  bool _matches(ModelOption model) =>
      _query.isEmpty ||
      model.displayLabel.toLowerCase().contains(_query.toLowerCase());
}
