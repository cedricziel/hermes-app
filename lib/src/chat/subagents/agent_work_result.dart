import 'dart:async';

import '../agent_work_transport.dart';
import '../gateway/gateway_rpc_client.dart';
import '../session_chat_transport.dart' show SessionTransportUnavailable;

/// What a call on a chat's agents came to.
sealed class AgentWorkResult<T> {
  const AgentWorkResult();
}

final class WorkOk<T> extends AgentWorkResult<T> {
  const WorkOk(this.value);
  final T value;
}

/// A read, and the chat's session is not attached on this connection: nothing
/// was sent.
final class WorkNotAttached<T> extends AgentWorkResult<T> {
  const WorkNotAttached();
}

/// The server does not have the method.
final class WorkUnsupported<T> extends AgentWorkResult<T> {
  const WorkUnsupported();
}

/// No answer came (timeout, or the connection closed after sending): the call
/// may have happened.
final class WorkLost<T> extends AgentWorkResult<T> {
  const WorkLost();
}

enum WorkFailureKind {
  /// 4000, 4002, 4012: the server did not accept the request.
  rejected,

  /// 4001, 4044: the connection does not hold the session, or the thing is
  /// not this session's.
  notOwned,

  /// 5xxx.
  server,

  /// The action never left the device: its session could not be attached.
  notSent,

  /// Any other error, or an answer of a shape the app does not know.
  other,
}

final class WorkFailed<T> extends AgentWorkResult<T> {
  const WorkFailed(this.kind);
  final WorkFailureKind kind;
}

/// Maps what a call threw to its result. Never throws.
AgentWorkResult<T> workResultOfError<T>(Object error) {
  if (error is AgentActionNotSent) {
    return const WorkFailed(WorkFailureKind.notSent);
  }
  if (error is GatewayRpcException) {
    final code = error.code;
    if (code == kGatewayMethodNotFound) return const WorkUnsupported();
    if (code == 4000 || code == 4002 || code == 4012) {
      return const WorkFailed(WorkFailureKind.rejected);
    }
    if (code == 4001 || code == 4044) {
      return const WorkFailed(WorkFailureKind.notOwned);
    }
    if (code >= 5000 && code < 6000) {
      return const WorkFailed(WorkFailureKind.server);
    }
    return const WorkFailed(WorkFailureKind.other);
  }
  if (error is GatewayRequestTimeout ||
      error is GatewayConnectionClosed ||
      error is TimeoutException ||
      // The chat's transport was replaced while the call ran: whether it
      // reached the server is not known.
      error is SessionTransportUnavailable) {
    return const WorkLost();
  }
  return const WorkFailed(WorkFailureKind.other);
}
