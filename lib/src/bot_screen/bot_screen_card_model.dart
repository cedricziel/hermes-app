import 'dart:typed_data';

import 'bot_screen_controller.dart';
import 'bot_screen_models.dart';

/// What the Bot screen card shows: exactly one state, chosen in this order.
/// Not offered, not installed, blocked, starting, off, error, then the
/// running screen.
///
/// A plain value, so the card draws from it without a controller.
sealed class BotScreenCardModel {
  const BotScreenCardModel({required this.screenRunning});

  /// What the card shows for [controller]'s state, or null when there is
  /// nothing to say yet (no answer so far) or the server has no Bot Screen
  /// feature.
  static BotScreenCardModel? from(
    BotScreenController controller, {
    Set<String> ownViewerHashes = const {},
  }) => fromState(
    status: controller.status,
    unsupported: controller.unsupported,
    starting: controller.starting,
    startError: controller.startError,
    failure: controller.failure,
    frame: controller.frame,
    suppressed: controller.suppressed,
    ownViewerHashes: ownViewerHashes,
  );

  /// [from] over the controller's fields. [ownViewerHashes] are the lease
  /// hashes of the viewer ids this app holds, which tell "You're in control"
  /// from someone else; the app holds none until `bot-screen-takeover`.
  static BotScreenCardModel? fromState({
    BotScreenStatus? status,
    bool unsupported = false,
    bool starting = false,
    BotScreenFailure? startError,
    BotScreenFailure? failure,
    Uint8List? frame,
    bool suppressed = false,
    Set<String> ownViewerHashes = const {},
  }) {
    if (unsupported) return null;
    if (status == null) {
      return failure == null ? null : BotScreenReadFailed(screenRunning: false);
    }
    final running = status.running;
    if (!status.supported) return BotScreenNotOffered(screenRunning: running);
    if (!status.installed) {
      final sandbox = status.placement != 'gateway';
      return BotScreenNotInstalled(
        command: sandbox ? null : status.installCommand,
        sandbox: sandbox,
        screenRunning: running,
      );
    }
    if (status.blocker case final blocker?) {
      return BotScreenBlocked(
        text: blocker,
        memoryMb: status.memoryAvailableMb,
        screenRunning: running,
      );
    }
    if (starting) return BotScreenStarting(screenRunning: running);
    if (!running) {
      return BotScreenOff(startFailure: startError, screenRunning: false);
    }
    if (failure != null) return BotScreenReadFailed(screenRunning: true);
    final lease = status.lease;
    if (suppressed || lease.holder == BotScreenHolder.human) {
      return BotScreenControlled(
        byYou:
            lease.holder == BotScreenHolder.human &&
            lease.viewerHash != null &&
            ownViewerHashes.contains(lease.viewerHash),
      );
    }
    return BotScreenShowing(
      bytes: frame,
      aspectRatio: _aspectRatio(status.geometry),
    );
  }

  /// Whether the server reports the screen as running.
  final bool screenRunning;

  /// Whether the card belongs in the Activity panel: while the screen runs,
  /// or while it does not and the open chat used it ([usedByChat]: a
  /// `computer_use` tool call).
  bool listed({required bool usedByChat}) => screenRunning || usedByChat;

  static double _aspectRatio(String? geometry) {
    final parts = geometry?.split('x');
    if (parts != null && parts.length == 2) {
      final width = int.tryParse(parts[0]);
      final height = int.tryParse(parts[1]);
      if (width != null && height != null && width > 0 && height > 0) {
        return width / height;
      }
    }
    return 16 / 10;
  }

  /// The fixed word the `bot_screen.card.shown` breadcrumb records.
  String get slug => switch (this) {
    BotScreenNotOffered() => 'not_offered',
    BotScreenNotInstalled() => 'not_installed',
    BotScreenBlocked() => 'blocked',
    BotScreenStarting() => 'starting',
    BotScreenOff() => 'off',
    BotScreenReadFailed() => 'error',
    BotScreenShowing() => 'frame',
    BotScreenControlled() => 'controlled',
  };
}

/// `supported: false`: Hermes uses the server's own display.
final class BotScreenNotOffered extends BotScreenCardModel {
  const BotScreenNotOffered({super.screenRunning = false});
}

/// The desktop packages are missing. [command] is the server's install
/// command (gateway placement only); [sandbox] is true when the screen lives
/// in the terminal backend's image, which needs the desktop stack.
final class BotScreenNotInstalled extends BotScreenCardModel {
  const BotScreenNotInstalled({
    this.command,
    this.sandbox = false,
    super.screenRunning = false,
  });

  final String? command;
  final bool sandbox;
}

/// The screen cannot start; [text] is the server's own words and [memoryMb]
/// the free memory when it reported it.
final class BotScreenBlocked extends BotScreenCardModel {
  const BotScreenBlocked({
    required this.text,
    this.memoryMb,
    super.screenRunning = false,
  });

  final String text;
  final int? memoryMb;
}

/// A Start Screen request is in flight.
final class BotScreenStarting extends BotScreenCardModel {
  const BotScreenStarting({super.screenRunning = false});
}

/// The screen is stopped; [startFailure] is why the last start failed.
final class BotScreenOff extends BotScreenCardModel {
  const BotScreenOff({this.startFailure, super.screenRunning = false});

  final BotScreenFailure? startFailure;
}

/// The screen's state or frame could not be read.
final class BotScreenReadFailed extends BotScreenCardModel {
  const BotScreenReadFailed({super.screenRunning = true});
}

/// Hermes holds the lease: the latest frame, or none yet ([bytes] null).
final class BotScreenShowing extends BotScreenCardModel {
  const BotScreenShowing({this.bytes, this.aspectRatio = 16 / 10})
    : super(screenRunning: true);

  final Uint8List? bytes;
  final double aspectRatio;
}

/// A person holds the lease, so no picture: [byYou] when it is this app's
/// own viewer.
final class BotScreenControlled extends BotScreenCardModel {
  const BotScreenControlled({this.byYou = false}) : super(screenRunning: true);

  final bool byYou;
}
