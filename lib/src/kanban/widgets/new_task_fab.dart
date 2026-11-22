import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../theme/focus_ring.dart';

/// The board's "New task" floating button. Its shape is not state-aware, so
/// the keyboard focus ring is a wrapper, 2 px outside its 16 px rounded rectangle (nothing
/// clips it).
class NewTaskFab extends StatelessWidget {
  const NewTaskFab({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => FocusRing.outside(
    radius: 16,
    child: FloatingActionButton.extended(
      onPressed: onPressed,
      icon: const AppIcon(AppIcons.add),
      label: Text(context.l10n.kanbanNewTaskAction),
    ),
  );
}
