import 'package:provider/provider.dart';

import '../chat/tool_image_loader.dart';

/// The loader of a window that holds no session of its own (a conversation
/// window, the quick panel). It is cleared when the main window locks, by the
/// window's screen, and ends with the window.
Provider<ToolImageLoader?> windowToolImageLoaderProvider() =>
    Provider<ToolImageLoader?>(
      create: (_) => ToolImageLoader(),
      dispose: (_, loader) => loader?.dispose(),
    );
