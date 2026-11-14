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
/// state that is still loading, failed or unsupported shows no card: its
/// options may be those of an earlier read.
ConnectCardData? connectCardFor(
  ModelOptionsState state,
  ModelOptions? options, {
  required String profile,
}) {
  if (options == null) return null;
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
  r'(\b(http|status|error code)[ :]*40[123]\b)|'
  r'unauthori[sz]ed|api[ _-]?key|authentication|'
  r'insufficient (credit|fund|balance|quota)|\bcredits?\b|\bquota\b|\bbilling\b',
  caseSensitive: false,
);

/// Whether the error a reply failed with reads as the model provider
/// refusing the request (a bad or missing key, no credit), which Model
/// providers can fix. Hermes reports these as text, so this matches the words
/// and status codes providers use; a failure it misses simply gets no action.
bool isProviderReplyError(String message) => _providerFailure.hasMatch(message);
