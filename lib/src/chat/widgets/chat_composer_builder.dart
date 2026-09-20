import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:material_ui/material_ui.dart' as mui;

import '../../share/shared_item.dart';
import '../../theme/hermes_theme.dart';
import 'input_card_frame.dart';

/// Shown under the attachment chips: Hermes gets the names, not the files.
const attachmentsNote = 'Only the file names are sent, not their contents.';

/// Builds flutter_chat_ui's [Composer] for the Hermes chat.
///
/// [controller] is shared with the screen so it can prefill shared text.
/// [attachments] show as removable chips above the input, and count as
/// sendable content on their own: the send button stays enabled and an empty
/// message is emitted through `Chat.onMessageSend`, which the screen pairs
/// with its pending attachments. The composer never clears the field itself:
/// the screen does once it accepts the send, so a refused send keeps the text.
WidgetBuilder buildChatComposer({
  required TextEditingController controller,
  required List<SharedFile> attachments,
  required ValueChanged<SharedFile> onRemoveAttachment,
}) {
  return (context) {
    final scheme = Theme.of(context).colorScheme;
    final hasAttachments = attachments.isNotEmpty;
    return Composer(
      textEditingController: controller,
      hintText: 'Message Hermes…',
      maxLines: 8,
      sendIcon: const Icon(Icons.arrow_upward),
      sendIconColor: scheme.primary,
      emptyFieldSendIconColor: context.hermesColors.subtleText,
      backgroundColor: scheme.surface,
      sigmaX: 0,
      sigmaY: 0,
      allowEmptyMessage: hasAttachments,
      inputClearMode: InputClearMode.never,
      sendButtonVisibilityMode: hasAttachments
          ? SendButtonVisibilityMode.always
          : SendButtonVisibilityMode.disabled,
      topWidget: hasAttachments
          ? _AttachmentChips(
              attachments: attachments,
              onRemove: onRemoveAttachment,
            )
          : null,
    );
  };
}

/// Supplies what flutter_chat_ui's [Composer] needs from `material_ui`, a
/// package separate from Flutter's own material library: a `Material`
/// ancestor, `MaterialLocalizations` and a theme seeded from the app's colors. Wrap the `Chat` in this; it cannot be
/// added from the composer builder because [Composer] returns a `Positioned`
/// that must stay a direct child of the chat's `Stack`.
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

class _AttachmentChips extends StatelessWidget {
  const _AttachmentChips({required this.attachments, required this.onRemove});

  final List<SharedFile> attachments;
  final ValueChanged<SharedFile> onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final file in attachments)
                InputChip(
                  avatar: Icon(
                    file.isImage
                        ? Icons.image_outlined
                        : Icons.insert_drive_file_outlined,
                    size: 16,
                  ),
                  label: Text(file.name),
                  deleteButtonTooltipMessage: 'Remove ${file.name}',
                  onDeleted: () => onRemove(file),
                ),
            ],
          ),
          const InputCardNote(attachmentsNote),
        ],
      ),
    );
  }
}
