import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../widgets/grouped_list.dart';
import '../widgets/settings_scaffold.dart';
import 'update_check_controller.dart';
import 'widgets/update_status_card.dart';

/// What the Updates row opens: whether Hermes is up to date, what changed,
/// and Check now. Applying an update is not offered here yet.
class UpdatePage extends StatefulWidget {
  const UpdatePage({super.key, required this.controller, this.version});

  /// Shared with the Server screen, which owns it.
  final UpdateCheckController controller;

  /// The version the server's status reported, for a check that names none.
  final String? version;

  @override
  State<UpdatePage> createState() => _UpdatePageState();
}

class _UpdatePageState extends State<UpdatePage> {
  @override
  void initState() {
    super.initState();
    if (!widget.controller.everChecked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.controller.check();
      });
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      final status = controller.status(fallbackVersion: widget.version);
      final checking = status is UpdateChecking;
      return SettingsScaffold(
        title: 'Update',
        previousTitle: 'Server',
        actions: [
          SettingsBarAction(
            key: const Key('update-refresh'),
            label: 'Check now',
            icon: AppIcons.refresh,
            onPressed: checking ? null : () => controller.check(force: true),
          ),
        ],
        body: GroupedListView(
          children: [
            if (status != null)
              UpdateStatusCard(
                status: status,
                onCheckNow: checking
                    ? null
                    : () => controller.check(force: true),
              ),
            if (status is UpdateAvailable || status is UpdateRollback)
              if (controller.changes.isNotEmpty)
                UpdateChangeList(changes: controller.changes),
          ],
        ),
      );
    },
  );
}
