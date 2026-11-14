import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:material_ui/material_ui.dart' as mui;
import 'package:provider/provider.dart';

import '../../share/shared_item.dart';
import '../../theme/material_ui_bridge.dart';
import '../../bot_mode/bot_chat_context.dart';
import '../queued_prompt.dart';
import '../slash_command.dart';
import '../../voice/dictation_controller.dart';
import '../../voice/dictation_view.dart';
import '../../voice/voice_message_recording.dart';
import '../activity/widgets/needs_you_dock.dart';
import 'chat_composer.dart';

/// Builds the Hermes [ChatComposer] for flutter_chat_ui's `Chat`, in place of
/// the package's own [Composer]. Sends go to `Chat.onMessageSend` and the
/// attach button to `Chat.onAttachmentTap`; see [ChatComposer] for the rest.
WidgetBuilder buildChatComposer({
  required TextEditingController controller,
  FocusNode? focusNode,
  DictationController? dictation,
  VoiceMessageRecording? voiceRecording,
  required List<SharedFile> attachments,
  required ValueChanged<SharedFile> onRemoveAttachment,
  bool replying = false,
  Future<void> Function()? onStop,
  List<QueuedPrompt> queued = const [],
  ValueChanged<QueuedPrompt>? onRemoveQueued,
  VoidCallback? onSendQueued,
  Widget? modelPill,
  List<SlashCommand> slashCommands = const [],
  bool commandRunning = false,
  Widget? queueView,
  BotChatContext? botContext,
  Object? Function()? sendTarget,
  bool sendHeld = false,
  bool draftHandedBack = false,
  NeedsYouDockBuilder? dock,
}) {
  Widget composer(
    ValueChanged<String> onSend,
    VoidCallback? onAttach,
    DictationView? dictationView,
  ) => ChatComposer(
    controller: controller,
    focusNode: focusNode,
    botContext: botContext,
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
    slashCommands: slashCommands,
    commandRunning: commandRunning,
    queueView: queueView,
    dictation: dictationView,
    recording: voiceRecording?.view,
    sendHeld: sendHeld,
    draftHandedBack: draftHandedBack,
  );
  return (context) => _ComposerSlot(
    builder: (onSend, onAttach) {
      final bar = ListenableBuilder(
        listenable: Listenable.merge([dictation, voiceRecording]),
        builder: (context, _) => composer(
          onSend,
          onAttach,
          dictation?.available == true && voiceRecording?.busy != true
              ? DictationView.of(
                  dictation!,
                  onSend: () => sendAfterDictation(
                    dictation,
                    controller,
                    onSend,
                    sendTarget,
                  ),
                )
              : null,
        ),
      );
      if (dock == null) return bar;
      // The dock shares the composer's box, so the height reported for the
      // transcript's padding includes it.
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ViewMetricsBuilder(
            // The keyboard is not in the Scaffold body's own MediaQuery,
            // which has consumed it, so ask the view.
            builder: (context, media) =>
                dock(context, needsYouCompactFor(media)),
          ),
          bar,
        ],
      );
    },
  );
}

/// Builds with the view's own metrics, the keyboard included (a Scaffold body
/// has consumed it from its own `MediaQuery`), and again when they change.
class ViewMetricsBuilder extends StatefulWidget {
  const ViewMetricsBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, MediaQueryData media) builder;

  @override
  State<ViewMetricsBuilder> createState() => _ViewMetricsBuilderState();
}

class _ViewMetricsBuilderState extends State<ViewMetricsBuilder>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeMetrics() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, MediaQueryData.fromView(View.of(context)));
}

/// Ends [dictation] and sends the draft once its transcript is in place.
///
/// Only a dictation that settled with a transcript, or heard nothing, sends:
/// not one that was cancelled (by the user, the app leaving the foreground or
/// a profile change) or failed, whose failure stays on screen. Nor does it
/// send when [sendTarget] (the chat) changed while the transcript was on its
/// way.
Future<void> sendAfterDictation(
  DictationController dictation,
  TextEditingController controller,
  ValueChanged<String> onSend,
  Object? Function()? sendTarget,
) async {
  final target = sendTarget?.call();
  await dictation.stop();
  await dictation.whenSettled();
  final outcome = dictation.lastOutcome;
  if (outcome != 'inserted' && outcome != 'empty') return;
  if (sendTarget != null && sendTarget() != target) return;
  if (outcome == 'empty') dictation.dismiss();
  // The chat sends attachments without text too, and ignores an empty send.
  onSend(controller.text.trim());
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
    return Localizations.override(
      context: context,
      delegates: const [mui.DefaultMaterialLocalizations.delegate],
      child: mui.Theme(
        data: buildMaterialUiTheme(Theme.of(context).colorScheme),
        child: mui.Material(type: mui.MaterialType.transparency, child: child),
      ),
    );
  }
}
