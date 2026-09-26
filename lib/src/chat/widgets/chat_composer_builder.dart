import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:material_ui/material_ui.dart' as mui;
import 'package:provider/provider.dart';

import '../../share/shared_item.dart';
import '../queued_prompt.dart';
import 'chat_composer.dart';

/// Builds the Hermes [ChatComposer] for flutter_chat_ui's `Chat`, in place of
/// the package's own [Composer]. Sends go to `Chat.onMessageSend` and the
/// attach button to `Chat.onAttachmentTap`; see [ChatComposer] for the rest.
WidgetBuilder buildChatComposer({
  required TextEditingController controller,
  required List<SharedFile> attachments,
  required ValueChanged<SharedFile> onRemoveAttachment,
  bool replying = false,
  Future<void> Function()? onStop,
  List<QueuedPrompt> queued = const [],
  ValueChanged<QueuedPrompt>? onRemoveQueued,
  VoidCallback? onSendQueued,
  Widget? modelPill,
}) {
  return (context) => _ComposerSlot(
    builder: (onSend, onAttach) => ChatComposer(
      controller: controller,
      onSend: onSend,
      onAttach: onAttach,
      attachments: attachments,
      onRemoveAttachment: onRemoveAttachment,
      replying: replying,
      onStop: onStop,
      queued: queued,
      onRemoveQueued: onRemoveQueued,
      onSendQueued: onSendQueued,
      modelPill: modelPill,
    ),
  );
}

/// Pins the composer to the bottom of the `Chat` stack and reports its
/// height, without the bottom safe area, so the message list is padded to
/// clear it, as the package's own [Composer] does. It must stay a direct child
/// of that stack, which is why it returns the [Positioned] itself.
class _ComposerSlot extends StatefulWidget {
  const _ComposerSlot({required this.builder});

  final Widget Function(ValueChanged<String> onSend, VoidCallback? onAttach)
  builder;

  @override
  State<_ComposerSlot> createState() => _ComposerSlotState();
}

class _ComposerSlotState extends State<_ComposerSlot> {
  final _key = GlobalKey();

  void _measureAfterFrame() =>
      WidgetsBinding.instance.addPostFrameCallback((_) => _measure());

  void _measure() {
    if (!mounted) return;
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    context.read<ComposerHeightNotifier>().setHeight(
      box.size.height - MediaQuery.paddingOf(context).bottom,
    );
  }

  @override
  Widget build(BuildContext context) {
    _measureAfterFrame();
    final onSend = context.read<OnMessageSendCallback?>();
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: NotificationListener<SizeChangedLayoutNotification>(
        onNotification: (_) {
          _measureAfterFrame();
          return true;
        },
        child: SizeChangedLayoutNotifier(
          child: ColoredBox(
            key: _key,
            color: Theme.of(context).colorScheme.surface,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.paddingOf(context).bottom,
              ),
              child: widget.builder(
                (text) => onSend?.call(text),
                context.read<OnAttachmentTapCallback?>(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Supplies what flutter_chat_ui's message widgets need from `material_ui`, a
/// package separate from Flutter's own material library: a `Material`
/// ancestor, `MaterialLocalizations` and a theme seeded from the app's
/// colors. Wrap the `Chat` in this.
class FlyerMaterialScope extends StatelessWidget {
  const FlyerMaterialScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Localizations.override(
      context: context,
      delegates: const [mui.DefaultMaterialLocalizations.delegate],
      child: mui.Theme(
        data: mui.ThemeData(
          colorScheme:
              mui.ColorScheme.fromSeed(
                seedColor: scheme.primary,
                brightness: scheme.brightness,
              ).copyWith(
                primary: scheme.primary,
                surface: scheme.surface,
                onSurface: scheme.onSurface,
              ),
        ),
        child: mui.Material(type: mui.MaterialType.transparency, child: child),
      ),
    );
  }
}
