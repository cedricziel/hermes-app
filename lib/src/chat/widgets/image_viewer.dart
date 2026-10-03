import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../widgets/named_icon_button.dart';

/// An image full screen, which can be zoomed and moved, closed and, when
/// [onSave] is given, saved. [onSave] answers whether the user saved it.
class ImageViewerPage extends StatelessWidget {
  const ImageViewerPage({
    super.key,
    required this.image,
    required this.name,
    this.onSave,
  });

  final ImageProvider image;
  final String name;
  final Future<bool> Function()? onSave;

  @override
  Widget build(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: NamedIconButton(
          label: 'Close',
          icon: AppIcons.close,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(name, overflow: TextOverflow.ellipsis),
        actions: [
          if (onSave != null)
            NamedIconButton(
              label: 'Save',
              icon: AppIcons.download,
              onPressed: () async {
                if (await onSave!()) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Saved $name')),
                  );
                }
              },
            ),
        ],
      ),
      body: InteractiveViewer(
        maxScale: 8,
        child: Center(
          child: Image(
            image: image,
            semanticLabel: name,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) =>
                const AppIcon(AppIcons.brokenImage, color: Colors.white54),
          ),
        ),
      ),
    );
  }
}
