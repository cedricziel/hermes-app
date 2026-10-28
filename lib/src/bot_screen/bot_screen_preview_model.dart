import 'dart:typed_data';

import 'bot_screen_card_model.dart';

/// What the still preview in the transcript shows: the running screen, a
/// person in control, or nothing.
///
/// A plain value, so the preview draws from it without a controller. Only a
/// screen that runs is worth a place in the transcript: every other state of
/// the card (not installed, blocked, off, an error) is [BotScreenPreviewHidden],
/// since the Activity panel's card is where those are explained.
sealed class BotScreenPreviewModel {
  const BotScreenPreviewModel();

  /// The preview for [card], the state the Activity panel's card would show;
  /// null (no answer yet, or a server without a Bot Screen) shows nothing.
  static BotScreenPreviewModel from(BotScreenCardModel? card) => switch (card) {
    BotScreenShowing(:final bytes, :final aspectRatio) => BotScreenPreviewFrame(
      bytes: bytes,
      aspectRatio: aspectRatio,
    ),
    BotScreenControlled(:final byYou) => BotScreenPreviewSuppressed(
      byYou: byYou,
    ),
    _ => const BotScreenPreviewHidden(),
  };

  /// Whether anything is drawn.
  bool get visible => this is! BotScreenPreviewHidden;
}

/// Nothing to draw.
final class BotScreenPreviewHidden extends BotScreenPreviewModel {
  const BotScreenPreviewHidden();
}

/// Hermes holds the lease: the latest frame, or none yet ([bytes] null).
final class BotScreenPreviewFrame extends BotScreenPreviewModel {
  const BotScreenPreviewFrame({this.bytes, this.aspectRatio = 16 / 10});

  final Uint8List? bytes;
  final double aspectRatio;
}

/// A person holds the lease, so there is no picture: [byYou] when it is this
/// app's own viewer.
final class BotScreenPreviewSuppressed extends BotScreenPreviewModel {
  const BotScreenPreviewSuppressed({this.byYou = false});

  final bool byYou;
}
