import 'package:flutter/material.dart';

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
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(name, overflow: TextOverflow.ellipsis),
        actions: [
          if (onSave != null)
            IconButton(
              tooltip: 'Save',
              icon: const Icon(Icons.download_outlined),
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
                const Icon(Icons.broken_image_outlined, color: Colors.white54),
          ),
        ),
      ),
    );
  }
}
