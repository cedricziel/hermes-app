part of 'chat_controller.dart';

/// What the activity line and the Mac toolbar read: stamps of the Working
/// sources, kept current as the controller changes.
extension _ChatControllerWorking on ChatController {
  /// Stamps every chat that has a Working source whenever the controller
  /// changes, so arrival order does not depend on who reads when, or on
  /// which chat is selected.
  void _refreshImpl() {
    try {
      for (final thread in {
        ..._sessionStates.keys,
        ..._processOutputs.keys,
        ..._moaStates.keys,
        for (final thread in _threads)
          if (thread.isReplying) thread,
        ?selectedThread,
      }) {
        workingSummaryIn(thread);
      }
    } on Object {
      // The line is a convenience; it must not break a change.
    }
  }

  bool _waitIsCurrentImpl(ChatThread thread, String kind) =>
      _workingSource.waitIsCurrent(
        thread,
        _sessionStates[thread]?.waitAt[kind],
        replying: thread.isReplying,
      );
}
