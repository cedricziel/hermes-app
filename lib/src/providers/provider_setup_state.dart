/// What the provider setup controller exposes. Plain values only: no display
/// text (the screen words them), and nothing here holds a typed key, a device
/// code or a message that could carry one.
library;

import 'provider_models.dart';

// ---- the key form ----

enum KeyFormPhase {
  /// Typing. Save is the primary action.
  editing,

  /// Hermes is checking the key.
  checking,
  saving,

  /// The provider answered 401 or 403: nothing was saved.
  rejected,

  /// The provider answered with an error status: nothing was saved yet.
  providerError,

  /// Hermes refused the save (a locked key, a redacted value).
  refused,

  /// The answer to the save was lost and the key may or may not be saved.
  /// The field is cleared and the person pastes the key again.
  unknown,
  saved,
}

/// What a saved key's confirmation says it was not able to check.
enum KeyNote {
  /// Hermes has no probe for the provider, or the key was saved with "Save
  /// anyway": "Your first chat will show whether the key works."
  unchecked,

  /// Hermes could not reach the provider to check.
  unreachable,
}

/// The one thing the bar's primary button (and Return) does.
enum KeyFormAction { save, editKey, saveAnyway }

/// What Hermes' check said, as the telemetry names it.
enum KeyCheckKind {
  accepted('accepted'),
  rejected('rejected'),
  providerError('provider_error'),
  unchecked('unchecked'),
  unreachable('unreachable');

  const KeyCheckKind(this.signal);
  final String signal;
}

class KeyFormState {
  const KeyFormState({
    required this.providerId,
    this.replacing = false,
    this.phase = KeyFormPhase.editing,
    this.message,
    this.emptyKey = false,
    this.note,
  });

  final String providerId;

  /// The form is "Replace key": a key for this variable is saved already.
  final bool replacing;
  final KeyFormPhase phase;

  /// Hermes' own sentence for a rejection, a provider error or a refusal.
  final String? message;

  /// Save was tapped with nothing but spaces: "Paste the key first".
  final bool emptyKey;

  /// Set once saved: what the confirmation must say.
  final KeyNote? note;

  bool get busy =>
      phase == KeyFormPhase.checking || phase == KeyFormPhase.saving;

  /// The bar's Save is hidden after a rejection and a provider error, so the
  /// form has one primary action; editing the key brings it back.
  bool get saveVisible =>
      phase != KeyFormPhase.rejected && phase != KeyFormPhase.providerError;

  bool get offersSaveAnyway =>
      phase == KeyFormPhase.rejected || phase == KeyFormPhase.providerError;

  /// "Try again" next to "Save anyway" after a provider error.
  bool get offersTryAgain => phase == KeyFormPhase.providerError;

  /// The primary action, or null while busy or done. [hasText] is whether the
  /// field holds anything: Save needs it, "Edit key" does not.
  KeyFormAction? primaryAction({required bool hasText}) => switch (phase) {
    KeyFormPhase.editing ||
    KeyFormPhase.refused ||
    KeyFormPhase.unknown => hasText ? KeyFormAction.save : null,
    KeyFormPhase.rejected => KeyFormAction.editKey,
    KeyFormPhase.providerError => hasText ? KeyFormAction.saveAnyway : null,
    KeyFormPhase.checking || KeyFormPhase.saving || KeyFormPhase.saved => null,
  };

  KeyFormState copyWith({
    KeyFormPhase? phase,
    String? message,
    bool clearMessage = false,
    bool? emptyKey,
    KeyNote? note,
  }) => KeyFormState(
    providerId: providerId,
    replacing: replacing,
    phase: phase ?? this.phase,
    message: clearMessage ? null : message ?? this.message,
    emptyKey: emptyKey ?? this.emptyKey,
    note: note ?? this.note,
  );
}

// ---- the default-model step ----

enum DefaultStepKind {
  /// Asking Hermes for its recommendation and reading the providers again.
  preparing,

  /// A default is saved: "New chats use &lt;model&gt;" with Change.
  saved,

  /// "Use &lt;model&gt; for new chats?" with Keep and Choose another.
  ask,

  /// Nothing recommended: "Choose a model for new chats". Nothing is saved
  /// and the provider's first listed model is never taken.
  choose,

  /// The provider lists no models yet: the recommended model alone with
  /// Retry. Nothing is saved until it does.
  modelsLoading,
}

class DefaultModelStep {
  const DefaultModelStep({
    required this.providerId,
    required this.kind,
    this.model,
    this.currentModel,
    this.movedByHermes = false,
    this.note,
    this.failed = false,
  });

  final String providerId;
  final DefaultStepKind kind;

  /// The model saved ([DefaultStepKind.saved]) or recommended.
  final String? model;

  /// The default the profile already had, for "Keep &lt;current model&gt;".
  final String? currentModel;

  /// Hermes moved the default itself during a sign-in.
  final bool movedByHermes;
  final KeyNote? note;

  /// A save of the default failed or was refused; nothing changed.
  final bool failed;

  DefaultModelStep copyWith({
    DefaultStepKind? kind,
    String? model,
    bool? movedByHermes,
    bool? failed,
  }) => DefaultModelStep(
    providerId: providerId,
    kind: kind ?? this.kind,
    model: model ?? this.model,
    currentModel: currentModel,
    movedByHermes: movedByHermes ?? this.movedByHermes,
    note: note,
    failed: failed ?? this.failed,
  );
}

/// Hermes wants the person to confirm an expensive model; nothing is saved
/// until "Use it anyway".
class ModelConfirmation {
  const ModelConfirmation({
    required this.providerId,
    required this.model,
    required this.message,
  });

  final String providerId;
  final String model;

  /// Hermes' own `confirm_message`.
  final String message;
}

enum DefaultSetOutcome { saved, needsConfirmation, refused, failed }

// ---- removing ----

enum RemovalKind { key, account, endpoint }

enum RemovalStatus { removed, alreadyGone, refused, unknown }

/// What a provider's detail can offer to remove, from its credentials.
sealed class RemovalAction {
  const RemovalAction();
  RemovalKind? get kind;
}

/// "Remove key" (`DELETE /api/env`).
class RemoveKeyAction extends RemovalAction {
  const RemoveKeyAction(this.keyEnv);
  final String keyEnv;
  @override
  RemovalKind get kind => RemovalKind.key;
}

/// "Sign out" (`DELETE /api/providers/oauth/{id}`).
class SignOutAction extends RemovalAction {
  const SignOutAction();
  @override
  RemovalKind get kind => RemovalKind.account;
}

/// "Delete endpoint".
class DeleteEndpointAction extends RemovalAction {
  const DeleteEndpointAction();
  @override
  RemovalKind get kind => RemovalKind.endpoint;
}

/// A sign-in Hermes cannot remove: show the command to run on the server, or
/// Hermes' hint. No button.
class ServerCommandAction extends RemovalAction {
  const ServerCommandAction({this.command, this.hint});
  final String? command;
  final String? hint;
  @override
  RemovalKind? get kind => null;
}

/// The removals [entry] offers. Hand-added pool keys are never removable
/// here. A sign-in whose credential comes from an API key (`env_var`) cannot
/// be signed out; Hermes' hint then points at the web dashboard, so the app
/// offers "Remove key" for the provider's key variable instead.
List<RemovalAction> removalActionsFor(ProviderEntry entry) {
  if (entry.method == ConnectMethod.endpoint) {
    return const [DeleteEndpointAction()];
  }
  final actions = <RemovalAction>[];
  final keyEnvs = <String>{
    for (final c in entry.credentials)
      if (c.kind == CredentialKind.apiKey && c.keyEnv != null) c.keyEnv!,
  };
  final account = entry.account;
  if (account != null) {
    if (entry.disconnectable) {
      actions.add(const SignOutAction());
    } else if (account.source == 'env_var') {
      final env = entry.keyEnv;
      if (env != null) keyEnvs.add(env);
    } else {
      actions.add(
        ServerCommandAction(
          command: entry.disconnectCommand,
          hint: entry.disconnectHint,
        ),
      );
    }
  }
  return [for (final env in keyEnvs) RemoveKeyAction(env), ...actions];
}

class RemovalResult {
  const RemovalResult({
    required this.providerId,
    required this.kind,
    required this.status,
    this.message,
    this.stillConnectedThrough = 0,
    this.stillConnected = false,
  });

  final String providerId;
  final RemovalKind? kind;
  final RemovalStatus status;

  /// Hermes' reason for a refusal.
  final String? message;

  /// After the re-read the provider is still connected, through this many
  /// other saved credentials (another key, a sign-in, hand-added keys).
  final int stillConnectedThrough;
  final bool stillConnected;
}

// ---- the custom endpoint form ----

enum EndpointFormPhase {
  idle,
  checking,

  /// The server reached the address; models and a warning may be present.
  checked,
  unreachable,
  checkFailed,
  saving,
  refused,
  unknown,
  saved,
}

enum EndpointIssue { nameMissing, addressMissing, addressScheme, modelMissing }

class EndpointFormState {
  const EndpointFormState({
    this.phase = EndpointFormPhase.idle,
    this.models = const [],
    this.resolvedBaseUrl,
    this.warning,
    this.message,
    this.issue,
    this.checkedAddress,
  });

  final EndpointFormPhase phase;
  final List<String> models;

  /// The address that answered, when it differs from what was typed: "Hermes
  /// will use <address>". It is saved in place of the typed one.
  final String? resolvedBaseUrl;

  /// Hermes' warning for `ok: false, reachable: true`; saving stays possible.
  final String? warning;

  /// Hermes' reason for a refused save.
  final String? message;

  /// A local check that stopped a save or check before anything was sent.
  final EndpointIssue? issue;

  /// The typed address the check was made for; a changed address makes the
  /// result stale.
  final String? checkedAddress;

  bool get busy =>
      phase == EndpointFormPhase.checking || phase == EndpointFormPhase.saving;
}

/// What a save of an endpoint came to.
enum EndpointSubmit {
  saved,

  /// The key field was cleared on an endpoint with a saved key: ask "Remove
  /// the saved key?" and call again with `confirmedClear`.
  needsClearConfirmation,

  /// A key would go to an `http://` address that is not local to the server:
  /// ask "Send the key unencrypted?" and call again with `confirmedCleartext`.
  needsCleartextConfirmation,

  /// A required field is missing; see [EndpointFormState.issue].
  invalid,
  refused,
  unknown,
}
