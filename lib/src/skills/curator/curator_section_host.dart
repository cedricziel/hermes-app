import 'package:flutter/widgets.dart';

import '../widgets/curator_section.dart';
import 'curator_controller.dart';
import 'curator_run_sheet.dart';
import 'curator_section_adapter.dart';

/// The curator section of the Skills screen: it follows [controller] on its
/// own, so a poll never rebuilds the list around it, and shows nothing while
/// the controller says it is hidden (a search or filter is active, or the
/// server has no curator).
class CuratorSectionHost extends StatelessWidget {
  const CuratorSectionHost({super.key, required this.controller});

  final CuratorController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      if (!controller.visible) return const SizedBox.shrink();
      return CuratorSection(
        model: curatorSectionModel(controller),
        callbacks: CuratorSectionCallbacks(
          onTryAgain: () => controller.reload(),
          onPausedChanged: (value) => controller.setPaused(value),
          onRunNow: () => askToRunCurator(context, controller),
          onCheckStatus: () => controller.checkStatus(),
        ),
      );
    },
  );
}
