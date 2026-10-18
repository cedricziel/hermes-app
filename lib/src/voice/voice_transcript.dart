import 'dart:convert';

import '../chat/chat_models.dart';
import '../chat/media/extract_media.dart';

/// Hermes sends the spoken text as `text_to_speech`'s `text` argument, not
/// as a transcript field in its result. Match the returned absolute path;
/// never infer a transcript from a caption or another clip's filename.
String? voiceTranscript(ChatAttachment attachment, Iterable<ToolCall> calls) {
  if (!attachment.isAudio || attachment.remotePath == null) return null;
  for (final call in calls.toList().reversed) {
    if (call.name != 'text_to_speech' ||
        call.status != ToolCallStatus.completed) {
      continue;
    }
    final text = call.args?['text'];
    if (text is! String || text.trim().isEmpty) continue;
    Object? data = call.resultData;
    if (data is! Map) {
      try {
        data = jsonDecode(call.result);
      } on FormatException {
        continue;
      }
    }
    if (data is! Map || data['success'] != true) continue;
    final paths = <String>{
      if (data['file_path'] case final String path) path,
      if (data['file_paths'] case final List paths)
        ...paths.whereType<String>(),
      if (data['media_tag'] case final String tag)
        ...extractMedia(tag).attachments.map((a) => a.remotePath!),
    };
    // A multi-file reply gives no per-file text boundaries. Showing the
    // entire input beside just one part would claim a transcript we lack.
    if (paths.length != 1) continue;
    if (data['delivery_file_count'] case final num count when count > 1) {
      continue;
    }
    if (paths.single == attachment.remotePath) return text.trim();
  }
  return null;
}
