/// Why a curator call did not produce a value. A kind, and for the two
/// failures the screen words itself with Hermes' text (a refused pause, a
/// failed spawn) the text of Hermes' `detail`, as received. The request that
/// failed (its URL carries the profile) never travels with it.
enum CuratorFailure {
  /// The request never left the device: no connection.
  offline,

  /// A read that got no answer in time. Reads may be repeated.
  timeout,

  /// 401 or 403 after the auth interceptor gave up.
  unauthorized,

  /// Hermes rejected the request (400, 422, another 4xx): nothing changed and
  /// nothing started.
  refused,

  /// 500 "Curator unavailable": the curator module could not load.
  unavailable,

  /// A run Hermes could not spawn: nothing started.
  spawnFailed,

  /// Any other answer of Hermes that says it failed.
  server,

  /// A read whose answer is not an object.
  unreadable,

  /// A pause or a run that got no usable answer, or one that is not Hermes':
  /// it may have been done. Settled by reading, never by sending again.
  lostAnswer,
}

/// The outcome of a curator call. The repository answers one of these
/// instead of throwing.
sealed class CuratorResult<T> {
  const CuratorResult();
}

final class CuratorOk<T> extends CuratorResult<T> {
  const CuratorOk(this.value);

  final T value;
}

/// The server has no such route (404 or 405, or a page where JSON was
/// expected): the curator section is hidden, not shown as an error.
final class CuratorUnsupported<T> extends CuratorResult<T> {
  const CuratorUnsupported();
}

/// Hermes says the profile does not exist (a 404 whose detail starts
/// `Profile '`, or a run's 500 that carries that 404). Not an old server.
final class CuratorProfileGone<T> extends CuratorResult<T> {
  const CuratorProfileGone();
}

final class CuratorFailed<T> extends CuratorResult<T> {
  const CuratorFailed(this.kind, {this.detail});

  final CuratorFailure kind;

  /// Hermes' own text, set only for a refused or failed pause
  /// ([CuratorFailure.refused], [CuratorFailure.server]) and a run that could
  /// not be spawned ([CuratorFailure.spawnFailed]). It can name a profile or a
  /// server path: it is raw, for the controller to clean and keep in screen
  /// state only, never to log, and never part of [toString].
  final String? detail;

  @override
  String toString() => 'CuratorFailed(${kind.name})';
}

/// `POST /api/curator/run` was accepted: a child process was spawned. How it
/// ends is read from the action status.
class CuratorRunStarted {
  const CuratorRunStarted();
}
