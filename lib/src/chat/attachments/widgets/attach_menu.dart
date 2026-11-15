import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import '../../../theme/app_icons.dart';
import '../../../theme/breakpoints.dart';
import '../attachment_source.dart';

/// The attach menu: one row per origin. A dialog (macOS or a wide layout) gets
/// a title; a phone sheet does not, since its handle and rows speak for
/// themselves.
class AttachMenu extends StatelessWidget {
  const AttachMenu({super.key, required this.origins, required this.onPick});

  final List<AttachOrigin> origins;
  final ValueChanged<AttachOrigin> onPick;

  @override
  Widget build(BuildContext context) {
    final dialog =
        Theme.of(context).platform == TargetPlatform.macOS ||
        isWideLayout(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (dialog)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Text(
                  context.l10n.chatAttachmentsMenuTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            for (final origin in origins)
              ListTile(
                leading: AppIcon(_icon(origin)),
                title: Text(_label(context, origin)),
                onTap: () => onPick(origin),
              ),
          ],
        ),
      ),
    );
  }
}

AppIconSet _icon(AttachOrigin origin) => switch (origin) {
  AttachOrigin.files => AppIcons.file,
  AttachOrigin.photos => AppIcons.photoLibrary,
  AttachOrigin.camera => AppIcons.camera,
};

String _label(BuildContext context, AttachOrigin origin) {
  final l10n = context.l10n;
  return switch (origin) {
    AttachOrigin.files => l10n.chatAttachmentsOriginFiles,
    AttachOrigin.photos => l10n.chatAttachmentsOriginPhotos,
    AttachOrigin.camera => l10n.chatAttachmentsOriginCamera,
  };
}
