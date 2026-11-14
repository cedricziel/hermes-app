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
/// the starter prompts.
ConnectCardData? connectCardFor(
  ModelOptionsState state,
  ModelOptions? options, {
  required String profile,
  ModelOptionsState settled = ModelOptionsState.loading,
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
    kind: options.warming ? ConnectCardKind.loading : ConnectCardKind.connect,
    profile: profile,
  );
}

final _providerFailure = RegExp(
  r'\b(http|status|error code)[ :]*(401|402|403|429)\b|'
  r'\b(invalid|incorrect|missing|expired|revoked|no)( \w+)? api[ _-]?key\b|'
  r'\bapi[ _-]?key (is |was )?(invalid|incorrect|missing|expired|revoked)\b',
  caseSensitive: false,
);

/// Whether the error a reply failed with reads as the model provider
/// refusing the request: an HTTP 401, 402, 403 or 429 status, or an invalid,
/// incorrect or missing API key. Hermes reports these as text, so this is a
/// match on words, kept narrow so that an MCP server's or a tool's failure
/// does not offer Model providers; a provider failure it misses simply gets
/// no action.
bool isProviderReplyError(String message) => _providerFailure.hasMatch(message);
