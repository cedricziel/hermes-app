/// What the provider forms, steps and cards draw. Plain values only, like
/// `provider_view_models.dart`: the widgets word them, and a mapper from the
/// controller's `KeyFormState`, `ProviderSignIn`, `EndpointFormState` and
/// `DefaultModelStep` builds them. Nothing here holds a typed key: the screen
/// owns the text controllers and hands them to the forms.
library;

import 'provider_view_models.dart';

// ---- the API key form ----

enum ApiKeyPhase {
  /// Typing. Save is the primary action.
  editing,

  /// Hermes is checking the key.
  checking,
  saving,

  /// The provider answered 401 or 403: nothing was saved.
  rejected,

  /// The provider answered with an error status: nothing was saved yet.
  providerError,

  /// Hermes refused the save (a locked key, a 422).
  refused,

  /// The answer to the save was lost and the key may or may not be saved: the
  /// form clears the field and asks for the key again.
  unknown,
}

/// What the form's primary button, and Return, do.
enum ApiKeyAction { save, editKey, saveAnyway }

class ApiKeyFormData {
  const ApiKeyFormData({
    required this.providerName,
    required this.profile,
    this.replacing = false,
    this.phase = ApiKeyPhase.editing,
    this.message,
    this.notAccepted = false,
    this.emptyKey = false,
    this.offersKeyLink = false,
    this.offersAccount = false,
  });

  final String providerName;
  final String profile;

  /// The form is "Replace key": a key is saved already and never shown.
  final bool replacing;
  final ApiKeyPhase phase;

  /// Hermes' own sentence for a rejection, a provider error or a refusal.
  final String? message;

  /// The save answered 422: the form says its own fixed sentence and never
  /// repeats anything of the answer.
  final bool notAccepted;

  /// Save was tapped with nothing typed: "Paste the key first".
  final bool emptyKey;

  /// Hermes gave an address for keys that passes the link check, so "Get a
  /// key from &lt;provider&gt;" is drawn; otherwise the row is left out.
  final bool offersKeyLink;

  /// The provider also signs in with an account ("Use an Anthropic account
  /// instead").
  final bool offersAccount;

  bool get busy => phase == ApiKeyPhase.checking || phase == ApiKeyPhase.saving;

  /// The bar's Save is hidden after a rejection and a provider error, so the
  /// form has one primary action; editing the key brings it back.
  bool get saveVisible =>
      phase != ApiKeyPhase.rejected && phase != ApiKeyPhase.providerError;

  /// "Save anyway" is offered, next to the one primary action.
  bool get offersSaveAnyway => !saveVisible;

  /// The primary action, or null while busy or when it needs text the field
  /// does not hold. "Edit key" needs none.
  ApiKeyAction? primaryAction({required bool hasText}) => switch (phase) {
    ApiKeyPhase.editing ||
    ApiKeyPhase.refused ||
    ApiKeyPhase.unknown => hasText ? ApiKeyAction.save : null,
    ApiKeyPhase.rejected => ApiKeyAction.editKey,
    ApiKeyPhase.providerError => hasText ? ApiKeyAction.saveAnyway : null,
    ApiKeyPhase.checking || ApiKeyPhase.saving => null,
  };
}

// ---- the account sign-in step ----

enum SignInStepPhase {
  /// The code is shown and Hermes is polled.
  waiting,
  declined,
  expired,

  /// Hermes reported an error; [SignInCodeData.message] when it said why.
  failed,

  /// Hermes refused to start; [SignInCodeData.message] has its sentence.
  startRefused,

  /// The request to start got no answer.
  startFailed,
}

class SignInCodeData {
  const SignInCodeData({
    required this.providerName,
    required this.profile,
    this.phase = SignInStepPhase.waiting,
    this.code,
    this.codeInLink = false,
    this.canOpen = true,
    this.offline = false,
    this.expiresInMinutes,
    this.message,
  });

  final String providerName;
  final String profile;
  final SignInStepPhase phase;

  /// The code as the provider gave it, grouped. Shown and copyable only; it
  /// is never logged and the step holds nothing once the sign-in ended.
  final String? code;

  /// The provider's link already carries the code (Nous): "Check that this
  /// code matches:".
  final bool codeInLink;

  /// The verification address passed the link check; false drops the Open
  /// button and the code stays.
  final bool canOpen;

  /// Two polls in a row failed.
  final bool offline;
  final int? expiresInMinutes;

  /// Hermes' sentence for a refusal or an error.
  final String? message;
}

// ---- the page that shows a command ----

class ServerCommandData {
  const ServerCommandData({
    required this.providerName,
    required this.profile,
    required this.command,
    this.checking = false,
  });

  final String providerName;
  final String profile;
  final String command;

  /// "Check again" is reading the providers.
  final bool checking;
}

// ---- the custom endpoint form ----

enum EndpointCheck {
  none,
  checking,

  /// The server reached the address and listed models.
  found,

  /// The server reached the address, which listed no models or answered with
  /// a warning ([EndpointFormData.warning]).
  noModels,
  unreachable,

  /// The check got no answer.
  failed,
}

/// What stopped a save before anything was sent.
enum EndpointFormIssue { none, name, address, scheme, model }

class EndpointFormData {
  const EndpointFormData({
    required this.profile,
    this.editing = false,
    this.endpointName = '',
    this.hasSavedKey = false,
    this.check = EndpointCheck.none,
    this.models = const [],
    this.selectedModel,
    this.resolvedAddress,
    this.checkedAddress = '',
    this.warning,
    this.keyNotSent = false,
    this.insecureKey = false,
    this.apiType = ProviderApiType.automatic,
    this.offersUseForNew = false,
    this.useForNew = false,
    this.currentModelName,
    this.saving = false,
    this.issue = EndpointFormIssue.none,
    this.refused = false,
    this.message,
    this.notAccepted = false,
    this.unknown = false,
  });

  final String profile;

  /// Editing a saved endpoint: the title names it and the key stays unless
  /// typed over.
  final bool editing;
  final String endpointName;

  /// The endpoint has a saved key: the field stays empty with "Saved key" as
  /// its placeholder, and "Remove saved key" is offered.
  final bool hasSavedKey;
  final EndpointCheck check;

  /// The models the check found.
  final List<String> models;
  final String? selectedModel;

  /// The address Hermes will use when it differs from the typed one.
  final String? resolvedAddress;

  /// The address the unreachable message names.
  final String checkedAddress;

  /// Hermes' own warning for `ok: false, reachable: true`.
  final String? warning;

  /// The check left the typed key out, because the address is `http://` and
  /// not local to the server.
  final bool keyNotSent;

  /// A key is typed and the address is `http://` and not local to the server:
  /// "This address isn't encrypted".
  final bool insecureKey;
  final ProviderApiType apiType;

  /// The profile already has a default model, so "Use for new chats" is a
  /// choice; otherwise the endpoint becomes the default and the footer says
  /// so.
  final bool offersUseForNew;
  final bool useForNew;

  /// The model the switch's footer says stays when it is off.
  final String? currentModelName;
  final bool saving;
  final EndpointFormIssue issue;

  /// Hermes refused the save, with [message] as its reason when it gave one.
  final bool refused;
  final String? message;

  /// The save answered 422: the form says its own fixed sentence.
  final bool notAccepted;

  /// The answer to the save was lost.
  final bool unknown;

  bool get busy => saving || check == EndpointCheck.checking;

  /// Save needs a name, an address and a model: the one picked from those
  /// found, or one typed by hand.
  bool canSave({
    required String name,
    required String address,
    required String typedModel,
  }) =>
      name.trim().isNotEmpty &&
      address.trim().isNotEmpty &&
      ((selectedModel ?? '').isNotEmpty || typedModel.trim().isNotEmpty);
}

// ---- the default-model step ----

enum DefaultStepView {
  /// A default is saved: "You're ready" with Change model.
  ready,

  /// "Use &lt;model&gt; for new chats?" with Keep and Choose another.
  later,

  /// Nothing recommended: "Choose a model for new chats".
  choose,

  /// The provider lists no models yet: the recommended model alone, Retry.
  loading,
}

/// What a saved key's note says it could not check.
enum DefaultStepNote { none, unchecked, unreachable }

class DefaultStepData {
  const DefaultStepData({
    required this.view,
    required this.providerName,
    required this.profile,
    this.modelName,
    this.currentModelName,
    this.note = DefaultStepNote.none,
    this.failed = false,
    this.busy = false,
  });

  final DefaultStepView view;
  final String providerName;
  final String profile;

  /// The model saved ([DefaultStepView.ready]) or recommended.
  final String? modelName;

  /// The default the profile already had, for "Keep &lt;current model&gt;".
  final String? currentModelName;
  final DefaultStepNote note;

  /// Saving the default failed or was refused; nothing changed.
  final bool failed;

  /// A save of the default is on its way.
  final bool busy;
}

// ---- the chat's cards ----

enum ConnectCardKind {
  /// Nothing is connected.
  connect,

  /// The default model's provider lost its key.
  reconnect,

  /// A provider is connected and its model list is not ready.
  loading,
}

class ConnectCardData {
  const ConnectCardData({
    required this.kind,
    required this.profile,
    this.modelName,
  });

  final ConnectCardKind kind;
  final String profile;

  /// The default model that lost its provider ([ConnectCardKind.reconnect]).
  final String? modelName;
}
