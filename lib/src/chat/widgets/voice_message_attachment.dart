import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../voice/voice_playback.dart';
import '../../voice/widgets/voice_message_view.dart';
import '../attachments/attachment_file_actions.dart';
import '../chat_models.dart';
import '../media/media_store.dart';
import '../media/media_source.dart';
import 'attachment_views.dart';

/// Connects the plain player view to the authenticated attachment cache and
/// the transcript's shared player. Merely displaying it downloads nothing.
class VoiceMessageAttachment extends StatefulWidget {
  const VoiceMessageAttachment({
    super.key,
    required this.attachment,
    required this.messageId,
    this.transcript,
  });

  final ChatAttachment attachment;
  final String messageId;
  final String? transcript;

  @override
  State<VoiceMessageAttachment> createState() => _VoiceMessageAttachmentState();
}

class _VoiceMessageAttachmentState extends State<VoiceMessageAttachment>
    with AttachmentFileActions<VoiceMessageAttachment> {
  @override
  ChatAttachment get attachment => widget.attachment;

  @override
  bool get hasFile =>
      attachmentHasFile(attachment, context.read<MediaStore?>(), local: true);

  @override
  void failedToFetch(MediaFailure reason) =>
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(SnackBar(content: Text(mediaFailureMessage(reason))));

  @override
  Widget build(BuildContext context) {
    final store = context.read<MediaStore?>();
    final playback = context.watch<VoicePlayback?>();
    // Outside a transcript (for example an older extension host), preserve
    // the file's Open/Save actions instead of presenting a dead player.
    if (playback == null || store == null) {
      return AttachmentCard(attachment: attachment);
    }
    final id =
        '${widget.messageId}:${attachment.fetchPath ?? attachment.path ?? attachment.name}';
    final active = playback.active == id;
    final available = hasFile;
    return VoiceMessageView(
      name: attachment.name,
      transcript: widget.transcript,
      playing: active && playback.playing,
      loading: active && playback.loading,
      position: active ? playback.position : Duration.zero,
      duration: active ? playback.duration : Duration.zero,
      error: !available
          ? 'This audio is unavailable on this device.'
          : active
          ? playback.error
          : null,
      onToggle: available && !playback.loading && (!active || playback.canRetry)
          ? () => unawaited(
              playback.toggle(
                id,
                () => stageAttachment(store, attachment, local: true),
              ),
            )
          : null,
      onSeek: active && !playback.loading ? playback.seek : null,
      onSave: available && !busy
          ? () => useFile(saveToDevice, local: true)
          : null,
    );
  }
}
