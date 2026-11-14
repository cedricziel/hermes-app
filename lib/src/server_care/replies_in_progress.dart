import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

/// How many replies the chat shows as still running, for the questions that
/// would stop them (an update restarts Hermes). The chat screen owns the
/// replies; it attaches a counter here for as long as it lives, so nothing
/// else needs its controller.
class RepliesInProgress {
  int Function()? _source;

  /// Replies running now; none while no chat is attached.
  int get count => _source?.call() ?? 0;

  void attach(int Function() source) => _source = source;

  /// Detaches [source] unless another counter took its place.
  void detach(int Function() source) {
    if (identical(_source, source)) _source = null;
  }
}

/// The replies running in the chat, or none outside an `AppShell`.
int repliesInProgressOf(BuildContext context) {
  try {
    return context.read<RepliesInProgress>().count;
  } on ProviderNotFoundException {
    return 0;
  }
}

/// The shell's counter, or null outside one, for a route that carries it
/// along.
RepliesInProgress? maybeRepliesInProgress(BuildContext context) {
  try {
    return context.read<RepliesInProgress>();
  } on ProviderNotFoundException {
    return null;
  }
}
