/// What the providers repository answers.
///
/// Reads and writes never throw and never hand a `DioException` on: its
/// request holds the body, and a body can hold a key. A result carries
/// Hermes' own `detail` sentence when the server gave a usable one, else a
/// fixed sentence. No result holds a key.
library;

import 'provider_models.dart';

/// The routes `ProvidersRepository.load` reads.
enum ProviderSource { options, env, oauth, endpoints, pool }

/// Why a source could not be read.
enum ReadFailure { unreachable, restartRequired, server, malformed }

/// What one source did.
sealed class SourceState {
  const SourceState();
}

class SourceOk extends SourceState {
  const SourceOk();
}

/// The server does not have the route (404).
class SourceNotOffered extends SourceState {
  const SourceNotOffered();
}

class SourceFailed extends SourceState {
  const SourceFailed(this.reason);
  final ReadFailure reason;
}

sealed class ProvidersSnapshot {
  const ProvidersSnapshot();
}

class ProvidersLoaded extends ProvidersSnapshot {
  const ProvidersLoaded(this.catalog, this.sources);

  final ProviderCatalog catalog;
  final Map<ProviderSource, SourceState> sources;

  SourceState state(ProviderSource source) =>
      sources[source] ?? const SourceNotOffered();

  bool failed(ProviderSource source) => state(source) is SourceFailed;
  bool offered(ProviderSource source) => state(source) is! SourceNotOffered;
}

/// `GET /api/model/options` answers 404: the server is older than the screen.
class ProvidersUnsupported extends ProvidersSnapshot {
  const ProvidersUnsupported();
}

class ProvidersFailed extends ProvidersSnapshot {
  const ProvidersFailed(this.reason);
  final ReadFailure reason;
}

/// The sentence for a 422: FastAPI echoes the submitted body in it, so the
/// body is never read.
const kNotAcceptedMessage = "Hermes didn't accept the request";

/// What Hermes' key check said.
sealed class KeyCheck {
  const KeyCheck();
}

class KeyAccepted extends KeyCheck {
  const KeyAccepted();
}

/// The provider answered 401 or 403.
class KeyRejected extends KeyCheck {
  const KeyRejected(this.message);
  final String message;
}

/// The provider answered something else ("Provider returned HTTP followed by a status").
class KeyProviderError extends KeyCheck {
  const KeyProviderError(this.message);
  final String message;
}

/// Hermes has no probe for this provider (or the server lacks the route).
class KeyUnchecked extends KeyCheck {
  const KeyUnchecked();
}

/// Hermes could not reach the provider, or the check itself failed or ran
/// out of time.
class KeyUnreachable extends KeyCheck {
  const KeyUnreachable();
}

sealed class KeySave {
  const KeySave();
}

class KeySaved extends KeySave {
  const KeySaved();
}

/// Hermes said no, and why: a redacted value, a locked or managed key.
class KeyRefused extends KeySave {
  const KeyRefused(this.message);
  final String message;
}

/// No answer, or an error after which the key may have been written. The
/// request is never sent again.
class KeySaveUnknown extends KeySave {
  const KeySaveUnknown();
}

sealed class RemoveResult {
  const RemoveResult();
}

class Removed extends RemoveResult {
  const Removed();
}

/// 404: what the person wanted removed is not there.
class AlreadyGone extends RemoveResult {
  const AlreadyGone();
}

/// A refusal with Hermes' reason when it gave one: a locked key, a sign-in it
/// cannot remove (400), nothing stored to remove (409).
class RemoveRefused extends RemoveResult {
  const RemoveRefused(this.message);
  final String? message;
}

/// No answer: the removal may have happened. Never resent.
class RemoveUnknown extends RemoveResult {
  const RemoveUnknown();
}

/// Hermes' suggestion for a new default model.
class RecommendedModel {
  const RecommendedModel(this.model, {this.freeTier = false});
  final String model;
  final bool freeTier;
}

sealed class DefaultModelResult {
  const DefaultModelResult();
}

class DefaultModelSaved extends DefaultModelResult {
  const DefaultModelSaved();
}

/// Hermes saved nothing: the model is an expensive one. Resend with
/// `confirmExpensive: true` only after the person agreed.
class DefaultModelConfirmRequired extends DefaultModelResult {
  const DefaultModelConfirmRequired(this.message);
  final String message;
}

class DefaultModelRefused extends DefaultModelResult {
  const DefaultModelRefused(this.message);
  final String? message;
}

/// No answer. Setting a default is idempotent, so trying again is safe.
class DefaultModelFailed extends DefaultModelResult {
  const DefaultModelFailed();
}

/// A started account sign-in. The code is meant to be typed elsewhere, but
/// it is never logged.
class SignInSession {
  const SignInSession({
    required this.sessionId,
    required this.userCode,
    required this.verificationUrl,
    required this.expiresIn,
    required this.pollInterval,
  });

  final String sessionId;
  final String userCode;
  final String verificationUrl;

  /// Seconds the session lives on the server.
  final int expiresIn;

  /// Seconds between polls, as the server asked.
  final int pollInterval;
}

sealed class SignInStart {
  const SignInStart();
}

class SignInStarted extends SignInStart {
  const SignInStarted(this.session);
  final SignInSession session;
}

/// Hermes refused (already signed in, no code from the provider, unknown
/// provider) with its sentence when it gave one.
class SignInStartRefused extends SignInStart {
  const SignInStartRefused(this.message);
  final String? message;
}

/// No answer.
class SignInStartFailed extends SignInStart {
  const SignInStartFailed();
}

enum SignInStatus { pending, approved, denied, expired, error, cancelled }

sealed class SignInPoll {
  const SignInPoll();
}

class SignInPolled extends SignInPoll {
  const SignInPolled(
    this.status, {
    this.errorMessage,
    this.accountEmail,
    this.retryAfter,
  });

  final SignInStatus status;
  final String? errorMessage;

  /// Present for Nous only.
  final String? accountEmail;
  final int? retryAfter;
}

/// 404: the session expired or the server restarted.
class SignInGone extends SignInPoll {
  const SignInGone();
}

/// The poll got no usable answer; the sign-in may still be going.
class SignInPollFailed extends SignInPoll {
  const SignInPollFailed();
}

enum SignInCancel { cancelled, notFound, failed }

sealed class EndpointCheck {
  const EndpointCheck();
}

/// The server could reach the address. [warning] is Hermes' message when it
/// answered `ok: false, reachable: true` (saving stays possible).
class EndpointChecked extends EndpointCheck {
  const EndpointChecked({
    this.models = const [],
    this.resolvedBaseUrl,
    this.warning,
  });

  final List<String> models;

  /// The address that answered, and the one to save.
  final String? resolvedBaseUrl;
  final String? warning;
}

class EndpointUnreachable extends EndpointCheck {
  const EndpointUnreachable();
}

/// No usable answer from the check itself.
class EndpointCheckFailed extends EndpointCheck {
  const EndpointCheckFailed();
}

sealed class EndpointSave {
  const EndpointSave();
}

class EndpointSaved extends EndpointSave {
  const EndpointSaved(this.id);
  final String? id;
}

class EndpointRefused extends EndpointSave {
  const EndpointRefused(this.message);
  final String message;
}

/// No answer: the endpoint may have been written. Never resent.
class EndpointSaveUnknown extends EndpointSave {
  const EndpointSaveUnknown();
}

sealed class EndpointActivation {
  const EndpointActivation();
}

class EndpointActivated extends EndpointActivation {
  const EndpointActivated();
}

class EndpointActivationRefused extends EndpointActivation {
  const EndpointActivationRefused(this.message);
  final String? message;
}

class EndpointActivationFailed extends EndpointActivation {
  const EndpointActivationFailed();
}
