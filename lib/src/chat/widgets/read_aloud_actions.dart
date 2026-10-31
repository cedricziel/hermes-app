import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../telemetry/breadcrumbs.dart';
import '../../voice/read_aloud.dart';
import '../../voice/voice_playback.dart';
import 'message_actions.dart' show ReadAloudState;

/// Binds a reply's Read aloud to the [ReadAloud] the chat screen provides and
/// the transcript's [VoicePlayback], and hands [builder] the plain state.
/// Without either, or with nothing to say, the state is null and Read aloud
/// is hidden. A voice call holds the audio, so Read aloud is disabled then,
/// as it is while another item loads.
class ReadAloudActions extends StatelessWidget {
  const ReadAloudActions({
    super.key,
    required this.messageId,
    required this.text,
    required this.builder,
  });

  final String messageId;
  final String text;
  final Widget Function(ReadAloudState? state, VoidCallback? onReadAloud)
  builder;

  @override
  Widget build(BuildContext context) {
    final readAloud = context.watch<ReadAloud?>();
    final playback = readAloud == null ? null : context.watch<VoicePlayback?>();
    if (readAloud == null || playback == null || speakableText(text).isEmpty) {
      return builder(null, null);
    }
    final id = ReadAloud.playbackId(messageId, text);
    final active = playback.active == id;
    final state = !active
        ? ReadAloudState.idle
        : playback.loading
        ? ReadAloudState.loading
        : playback.playing
        ? ReadAloudState.playing
        : ReadAloudState.idle;
    return builder(
      state,
      // While another reply or voice message loads, the player takes nothing.
      playback.blocked || playback.loading && !active
          ? null
          : () => unawaited(_pressed(context, readAloud, playback, state)),
    );
  }

  Future<void> _pressed(
    BuildContext context,
    ReadAloud readAloud,
    VoicePlayback playback,
    ReadAloudState state,
  ) async {
    final breadcrumbs = _breadcrumbs(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (state != ReadAloudState.idle) {
      breadcrumbs('chat.read_aloud', {'action': 'stop'});
      // Stopping starts the reply over next time, unlike a voice message,
      // and abandons speech Hermes is still making.
      readAloud.cancel();
      await playback.pause();
      if (state == ReadAloudState.playing) {
        await playback.seek(Duration.zero);
      }
      return;
    }
    breadcrumbs('chat.read_aloud', {'action': 'start'});
    final id = ReadAloud.playbackId(messageId, text);
    await playback.toggle(id, () => readAloud.fetch(text));
    if (playback.active == id && playback.error != null) {
      breadcrumbs('chat.read_aloud', {'action': 'failed'});
      messenger?.showSnackBar(
        const SnackBar(
          content: Text("Couldn't read this reply aloud. Try again."),
        ),
      );
    }
  }

  static Breadcrumbs _breadcrumbs(BuildContext context) {
    try {
      return context.read<Breadcrumbs>();
    } on ProviderNotFoundException {
      return Breadcrumbs.none;
    }
  }
}
