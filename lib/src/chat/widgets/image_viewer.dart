import 'package:material_ui/material_ui.dart';

import '../../theme/app_icons.dart';
import '../../widgets/named_icon_button.dart';
import '../../widgets/zoom_keyboard_shortcuts.dart';

/// The fallback viewer outside iOS. iOS chat photos use native Quick Look.
/// An image full screen, which can be zoomed and moved (also from the
/// keyboard, see `ZoomKeyboardShortcuts`), closed and, when [onSave] is
/// given, saved. [onSave] answers whether the user saved it.
class ImageViewerPage extends StatefulWidget {
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
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> {
  static const _maxScale = 8.0;

  final _transform = TransformationController();

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

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
        title: Text(widget.name, overflow: TextOverflow.ellipsis),
        actions: [
          if (widget.onSave != null)
            NamedIconButton(
              label: 'Save',
              icon: AppIcons.download,
              onPressed: () async {
                if (await widget.onSave!()) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Saved ${widget.name}')),
                  );
                }
              },
            ),
        ],
      ),
      body: ZoomKeyboardShortcuts(
        controller: _transform,
        maxScale: _maxScale,
        child: InteractiveViewer(
          transformationController: _transform,
          maxScale: _maxScale,
          child: Center(
            child: Image(
              image: widget.image,
              semanticLabel: widget.name,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  const AppIcon(AppIcons.brokenImage, color: Colors.white54),
            ),
          ),
        ),
      ),
    );
  }
}
