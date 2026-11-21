import 'package:flutter/cupertino.dart';

import '../../l10n/l10n.dart';

/// One entry of [showAppActionSheet]: [value] is what the sheet answers when
/// the entry is tapped.
class AppActionSheetEntry<T> {
  const AppActionSheetEntry({
    required this.label,
    required this.value,
    this.destructive = false,
  });

  final String label;
  final T value;
  final bool destructive;
}

/// The iOS action sheet: a one-line [title], one button per entry and Cancel
/// (`widgetsCancel`).
/// Answers the tapped entry's value, or null for Cancel and a tap outside.
Future<T?> showAppActionSheet<T>({
  required BuildContext context,
  required String title,
  required List<AppActionSheetEntry<T>> entries,
}) {
  return showCupertinoModalPopup<T>(
    context: context,
    builder: (sheet) => CupertinoActionSheet(
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      actions: [
        for (final entry in entries)
          CupertinoActionSheetAction(
            isDestructiveAction: entry.destructive,
            onPressed: () => Navigator.of(sheet).pop(entry.value),
            child: Text(entry.label),
          ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.of(sheet).pop(),
        child: Text(context.l10n.widgetsCancel),
      ),
    ),
  );
}
