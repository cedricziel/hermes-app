/// What the provider list and detail widgets draw. Plain values only: the
/// widgets word them, and a mapper from `ProviderEntry` and the controller's
/// state builds them, so nothing here knows a controller or a repository.
library;

/// How a provider row says the provider is, or can be, connected.
enum ProviderConnection {
  /// Connected with an API key, ending in `lastFour` when the server shows
  /// them, else "API key saved".
  key,

  /// Connected with an account, as `email` when Hermes reported it.
  signedIn,

  /// A custom endpoint, with the host of its address.
  endpoint,

  /// Connected, but the server does not say how (its keys cannot be read).
  connected,

  /// An account sign-in that has started and is not finished.
  pendingSignIn,

  /// Not connected; connects with an API key.
  offerKey,

  /// Not connected; connects by signing in to an account.
  offerAccount,

  /// Not connected; set up with a command on the server.
  offerOnServer,

  /// The "Custom endpoint" entry of "Add a provider".
  offerEndpoint,
}

/// One provider in the list.
class ModelProviderRowData {
  const ModelProviderRowData({
    required this.id,
    required this.name,
    required this.connection,
    this.lastFour,
    this.email,
    this.host,
    this.isDefault = false,
    this.warning,
  });

  /// The provider's slug, handed back to the callbacks.
  final String id;
  final String name;
  final ProviderConnection connection;

  /// The last four characters of the saved key, never more.
  final String? lastFour;
  final String? email;

  /// The host of a custom endpoint's address.
  final String? host;

  /// Whether it serves the profile's default model.
  final bool isDefault;

  /// A line Hermes reports about it, such as "Rate limited until 14:20".
  final String? warning;

  bool get isPending => connection == ProviderConnection.pendingSignIn;
}

/// The default model row at the top of the list.
class ProviderDefaultModelData {
  const ProviderDefaultModelData({
    required this.name,
    required this.providerName,
    this.id,
  });

  /// The model's display name, or its id when Hermes gives no name.
  final String name;

  /// The id, set only when it differs from [name].
  final String? id;
  final String providerName;
}

/// Where the list is in its life.
enum ProviderListStatus {
  /// Waiting for the first answer.
  loading,
  loaded,

  /// The model list itself failed, so there is nothing to show.
  failed,

  /// The server could not be reached and nothing was loaded before.
  offline,
}

/// Everything the list body shows.
class ProviderListData {
  const ProviderListData({
    required this.profile,
    this.status = ProviderListStatus.loaded,
    this.failureReason,
    this.staleOffline = false,
    this.restartRequired = false,
    this.defaultModel,
    this.connected = const [],
    this.recommended = const [],
    this.more = const [],
    this.endpointOffered = true,
    this.keysFailed = false,
    this.accountsFailed = false,
    this.endpointsFailed = false,
  });

  final String profile;
  final ProviderListStatus status;

  /// Hermes' own short reason for [ProviderListStatus.failed], when it is one
  /// of ours.
  final String? failureReason;

  /// The server cannot be reached while an older list is still shown.
  final bool staleOffline;
  final bool restartRequired;

  /// Null hides the default model group.
  final ProviderDefaultModelData? defaultModel;

  /// Connected providers, then any pending sign-ins.
  final List<ModelProviderRowData> connected;

  /// The recommended providers not yet connected.
  final List<ModelProviderRowData> recommended;
  final List<ModelProviderRowData> more;

  /// False when the server does not offer custom endpoints: the entry is
  /// absent, with no message.
  final bool endpointOffered;
  final bool keysFailed;
  final bool accountsFailed;
  final bool endpointsFailed;

  /// How many providers are connected, not counting a sign-in still waiting.
  int get connectedCount => connected.where((p) => !p.isPending).length;

  /// How many entries "Add a provider" offers.
  int get addableCount =>
      recommended.length + more.length + (endpointOffered ? 1 : 0);
}

/// What a provider's first line says.
enum ProviderStatusKind { key, signedIn, endpoint, serverKey, none }

/// Which account a signed-in row names; Hermes' own source label is never
/// shown, since it can be a path on the server.
enum ProviderAccountLabel { none, nousPortal, chatGpt }

enum ProviderCredentialKind {
  /// A key saved from the app: can be replaced.
  apiKey,
  account,

  /// A key someone added on the server: read-only.
  serverKey,
}

class ProviderCredentialData {
  const ProviderCredentialData({
    required this.kind,
    this.id = '',
    this.lastFour,
    this.account = ProviderAccountLabel.none,
  });

  /// Handed back by Replace key; the key's variable.
  final String id;
  final ProviderCredentialKind kind;
  final String? lastFour;
  final ProviderAccountLabel account;
}

enum ProviderApiType {
  automatic,
  chatCompletions,
  responses,
  anthropicMessages,
}

class ProviderEndpointData {
  const ProviderEndpointData({
    required this.address,
    this.apiType = ProviderApiType.automatic,
    this.hasKey = false,
  });

  final String address;
  final ProviderApiType apiType;
  final bool hasKey;
}

enum ProviderRemovalKind { removeKey, signOut, deleteEndpoint }

class ProviderRemovalData {
  const ProviderRemovalData(this.kind, {this.id = ''});

  final ProviderRemovalKind kind;

  /// Handed back to the callback; a key's variable.
  final String id;
}

/// Everything a provider's detail shows.
class ProviderDetailData {
  const ProviderDetailData({
    required this.name,
    required this.profile,
    required this.status,
    this.email,
    this.defaultModel,
    this.credentials = const [],
    this.endpoint,
    this.models = const [],
    this.modelCount = 0,
    this.removals = const [],
    this.serverCommand,
    this.removalHint,
    this.stillConnectedThrough = 0,
  });

  final String name;
  final String profile;
  final ProviderStatusKind status;
  final String? email;

  /// Set when the provider serves the profile's default model.
  final ProviderDefaultModelData? defaultModel;
  final List<ProviderCredentialData> credentials;
  final ProviderEndpointData? endpoint;

  /// The model ids Hermes lists, and how many the provider has in all.
  final List<String> models;
  final int modelCount;

  /// The removals that fit the credential, in order. Empty when there is
  /// nothing the app may remove.
  final List<ProviderRemovalData> removals;

  /// A sign-in Hermes cannot remove: the command to run on the server, and
  /// Hermes' own hint when it gave one.
  final String? serverCommand;
  final String? removalHint;

  /// After a removal left other credentials: how many.
  final int stillConnectedThrough;
}
