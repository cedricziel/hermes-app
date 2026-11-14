/// Why a server-care call did not produce a value.
enum CareFailureKind {
  /// A connection error or a timeout.
  offline,

  /// 401 or 403 after the auth interceptor gave up.
  unauthorized,

  /// Another 4xx; [CareFailed.message] is Hermes' `detail` when it sent one.
  refused,

  /// 5xx.
  server,

  /// A 200 whose body cannot be read at all.
  unreadable,

  /// Usage only: 503, Hermes cannot read its session store.
  storeUnreadable,
}

/// The outcome of a server-care call. The repository returns one of these
/// instead of throwing.
sealed class CareResult<T> {
  const CareResult();
}

final class CareOk<T> extends CareResult<T> {
  const CareOk(this.value);

  final T value;
}

/// The route is missing on this server (404, 405 or a non-JSON body): the part
/// that needs it is hidden, not shown as an error.
final class CareUnsupported<T> extends CareResult<T> {
  const CareUnsupported();
}

final class CareFailed<T> extends CareResult<T> {
  const CareFailed(this.kind, {this.message});

  final CareFailureKind kind;

  /// Hermes' own text when it sent a string `detail`. Shown to the person,
  /// never logged.
  final String? message;
}
