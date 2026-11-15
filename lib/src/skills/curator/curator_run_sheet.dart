import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/breakpoints.dart';
import '../../widgets/adaptive_sheet.dart';
import '../widgets/curator_run_confirmation.dart';
import 'curator_controller.dart';
import 'curator_section_adapter.dart';

/// Asks whether to start a curator pass, then starts it, once.
///
/// [CuratorController.beginRun] opens the question (it refuses when Run now
/// is off); Cancel, back, Escape and a drag all end as a null result and
/// [CuratorController.cancelRun], which sends nothing. Run now closes the
/// sheet first and then calls [CuratorController.confirmRun] exactly once; the
/// controller sends the POST once and never again. A sheet that goes away
/// without an answer (the profile changed, App Lock covered the app, the
/// screen was left) is a cancel too: the controller drops its question and
/// the sheet closes itself.
///
/// [host] is read when the question is shown, from the root navigator so a
/// phone shows the sheet over the whole screen.
Future<void> askToRunCurator(
  BuildContext host,
  CuratorController controller,
) async {
  controller.beginRun();
  if (controller.confirmation == null || !host.mounted) return;
  final root = Navigator.of(host, rootNavigator: true).context;
  final bool? confirmed;
  try {
    confirmed = await showAdaptiveSheet<bool>(
      root,
      builder: (sheet) => _CuratorRunSheet(controller: controller),
    );
  } on Object {
    controller.cancelRun();
    rethrow;
  }
  if (confirmed == true && !controller.disposed) {
    unawaited(controller.confirmRun());
  } else {
    controller.cancelRun();
  }
}

class _CuratorRunSheet extends StatefulWidget {
  const _CuratorRunSheet({required this.controller});

  final CuratorController controller;

  @override
  State<_CuratorRunSheet> createState() => _CuratorRunSheetState();
}

class _CuratorRunSheetState extends State<_CuratorRunSheet> {
  var _decided = false;
  var _closing = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  /// The controller dropped its question (profile switch, App Lock, the
  /// screen going away): the sheet closes without an answer.
  void _changed() {
    if (!_decided && widget.controller.confirmation == null) _close(null);
  }

  void _close(bool? result) {
    if (_closing) return;
    _closing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final route = ModalRoute.of(context);
      if (route != null && route.isCurrent) {
        Navigator.of(context).pop(result);
      } else if (route != null && route.isActive) {
        Navigator.of(context).removeRoute(route);
      }
    });
  }

  void _cancel() {
    if (_decided) return;
    _decided = true;
    widget.controller.cancelRun();
    Navigator.of(context).pop(false);
  }

  void _run() {
    if (_decided) return;
    _decided = true;
    _closing = true;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => CuratorRunConfirmation(
        model: curatorConfirmationModel(controller),
        onCancel: _cancel,
        onRun: _run,
        dialog:
            Theme.of(context).platform == TargetPlatform.macOS ||
            isWideLayout(context),
      ),
    );
  }
}
