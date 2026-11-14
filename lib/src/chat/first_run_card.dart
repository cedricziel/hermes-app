import '../models/model_options_state.dart';
import '../models/model_provider_option.dart';
import '../providers/widgets/provider_form_models.dart';

/// The card that replaces the welcome view's starter prompts when the profile
/// has no usable model, or null while the prompts show.
///
/// A default model whose provider lost its credential comes first, even while
/// another provider is ready and the state is [ModelOptionsState.ready]. With
/// no provider usable ([ModelOptionsState.incomplete]) a connected provider
/// that lists no models yet is "loading", anything else asks to connect. A
/// failed or unsupported state shows no card: its options may be those of an
/// earlier read. While the options are read again ([ModelOptionsState.loading])
/// the card of the [settled] state before stays, so a refresh never flashes
/// the starter prompts. A "loading" answer that a "Check again" left
/// unchanged ([warmingUnchanged]) asks to connect instead, so an older server
/// cannot keep the card waiting forever.
ConnectCardData? connectCardFor(
  ModelOptionsState state,
  ModelOptions? options, {
  required String profile,
  ModelOptionsState settled = ModelOptionsState.loading,
  bool warmingUnchanged = false,
}) {
  if (options == null) return null;
  if (state == ModelOptionsState.loading) state = settled;
  if (state != ModelOptionsState.ready &&
      state != ModelOptionsState.incomplete) {
    return null;
  }
  final missing = options.missing;
  if (missing != null) {
    return ConnectCardData(
      kind: ConnectCardKind.reconnect,
      profile: profile,
      modelName: missing.modelId,
      providerId: missing.providerId,
    );
  }
  if (state != ModelOptionsState.incomplete) return null;
  return ConnectCardData(
    kind: options.warming && !warmingUnchanged
        ? ConnectCardKind.loading
        : ConnectCardKind.connect,
    profile: profile,
  );
}

final _providerFailure = RegExp(
  r"\b(http|status( code)?|error code|client error '?)[ :]*(401|402|403|429)\b|"
  r'\b(401 unauthorized|402 payment required|403 forbidden|429 too many requests)|'
  r'\b(invalid|incorrect|missing|expired|revoked|no)( \w+)? api[ _-]?key\b|'
  r'\bapi[ _-]?key (is |was )?(invalid|incorrect|missing|expired|revoked)\b|'
  r'\bcredit balance (is )?too low\b|\binsufficient (credits?|funds|balance)\b',
  caseSensitive: false,
);

/// What marks a failure as a tool's or a helper model's rather than the chat
/// model's: a snake_case tool name before "failed" or "error", or the name of
/// a tool, a helper model or an auxiliary task.
final _notTheChatModel = RegExp(
  r'^\s*[a-z][a-z0-9]*(_[a-z0-9]+)+ (failed|error)\b|'
  r'\b(web[ _]?(search|extract)|tavily|vision|auxiliary|helper|mcp|tool)\b',
  caseSensitive: false,
);

/// Whether the error a reply failed with reads as the model provider
/// refusing the request: an HTTP 401, 402, 403 or 429 status (also as
/// "status code 401", "Client error '401 Unauthorized'" or "401 Unauthorized"),
/// an invalid, incorrect or missing API key, or the provider's own refusal for
/// money ("Your credit balance is too low", which arrives as a 400). The
/// credit phrases count although the status is not on the list, since nothing
/// else would say it. Hermes reports these as text, so this is a match on
/// words, kept narrow: an error that names a tool, a helper model or an
/// auxiliary task never matches, so Model providers is not offered for the
/// wrong key. A provider failure it misses simply gets no action.
bool isProviderReplyError(String message) =>
    !_notTheChatModel.hasMatch(message) && _providerFailure.hasMatch(message);
