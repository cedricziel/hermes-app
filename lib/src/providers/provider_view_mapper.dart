/// Turns the provider controllers' state into the plain view models the
/// widgets in `widgets/` draw. Pure functions: nothing here words anything for
/// the screen (the widgets do, through their l10n lookups), reads a text
/// field or holds a key.
library;

import '../models/model_provider_option.dart';
import 'provider_models.dart';
import 'provider_results.dart' hide EndpointCheck;
import 'provider_setup_controller.dart';
import 'provider_sign_in.dart';
import 'widgets/provider_form_models.dart';
import 'widgets/provider_view_models.dart';

/// The slug the server's `model/set` and the chat's model choices use for
/// [entry]: an endpoint is `custom:<id>`, every other provider its own id.
String providerSlugOf(ProviderEntry entry) =>
    entry.method == ConnectMethod.endpoint ? 'custom:${entry.id}' : entry.id;

/// The entry a slug (the server's, or an endpoint's `custom:<id>`) names.
ProviderEntry? entryForSlug(ProviderCatalog? catalog, String slug) {
  if (catalog == null) return null;
  final direct = catalog.byId(slug);
  if (direct != null) return direct;
  if (slug.startsWith('custom:')) return catalog.byId(slug.substring(7));
  return null;
}

/// The host of an endpoint's address, for "Custom endpoint · host".
String hostOfAddress(String address) {
  final uri = Uri.tryParse(address.trim());
  final host = uri?.host ?? '';
  if (host.isEmpty) return address.trim();
  return uri!.hasPort ? '$host:${uri.port}' : host;
}

ModelProviderRowData _connectedRow(
  ProviderEntry entry,
  ProviderSetupController controller,
) {
  final key = entry.credentials
      .where((c) => c.kind == CredentialKind.apiKey)
      .firstOrNull;
  final ProviderConnection connection;
  String? lastFour;
  String? email;
  if (entry.method == ConnectMethod.endpoint) {
    connection = ProviderConnection.endpoint;
  } else if (key != null) {
    connection = ProviderConnection.key;
    lastFour = key.lastFour;
  } else if (entry.account != null) {
    connection = ProviderConnection.signedIn;
    email = controller.signInFor(entry.id)?.accountEmail;
  } else {
    connection = ProviderConnection.connected;
  }
  return ModelProviderRowData(
    id: entry.id,
    name: entry.name,
    connection: connection,
    lastFour: lastFour,
    email: email,
    host: entry.endpoint == null
        ? null
        : hostOfAddress(entry.endpoint!.baseUrl),
    isDefault: entry.isDefault,
    warning: entry.warning,
  );
}

ModelProviderRowData _offerRow(ProviderEntry entry) => ModelProviderRowData(
  id: entry.id,
  name: entry.name,
  connection: switch (entry.method) {
    ConnectMethod.key => ProviderConnection.offerKey,
    ConnectMethod.account => ProviderConnection.offerAccount,
    ConnectMethod.onServer ||
    ConnectMethod.endpoint => ProviderConnection.offerOnServer,
  },
  warning: entry.warning,
);

/// The list body's data for [controller]'s state. [restartReason] is the
/// sentence for a read that failed because the server needs a restart, from
/// the screen's l10n.
ProviderListData providerListData(
  ProviderSetupController controller, {
  required String profile,
  required String restartReason,
}) {
  final loaded = controller.loaded;
  final failure = controller.failure;
  if (loaded == null) {
    if (controller.unsupported) {
      return ProviderListData(
        profile: profile,
        status: ProviderListStatus.failed,
      );
    }
    return switch (failure) {
      null => ProviderListData(
        profile: profile,
        status: ProviderListStatus.loading,
      ),
      ReadFailure.unreachable => ProviderListData(
        profile: profile,
        status: ProviderListStatus.offline,
      ),
      ReadFailure.restartRequired => ProviderListData(
        profile: profile,
        status: ProviderListStatus.failed,
        failureReason: restartReason,
      ),
      ReadFailure.server || ReadFailure.malformed => ProviderListData(
        profile: profile,
        status: ProviderListStatus.failed,
      ),
    };
  }
  final catalog = loaded.catalog;
  final accountsFailed = loaded.failed(ProviderSource.oauth);
  final pending = controller.pendingSignIns;
  final pendingIds = {for (final s in pending) s.providerId};

  final connected = [
    for (final entry in catalog.connected) _connectedRow(entry, controller),
    for (final signIn in pending)
      if (catalog.byId(signIn.providerId)?.connected != true)
        ModelProviderRowData(
          id: signIn.providerId,
          name: catalog.byId(signIn.providerId)?.name ?? signIn.providerId,
          connection: ProviderConnection.pendingSignIn,
        ),
  ];

  bool offered(ProviderEntry e) =>
      !pendingIds.contains(e.id) &&
      // Without the account list no account sign-in can start, and the
      // skeleton rows of those providers would read as "set up on your
      // server".
      !(accountsFailed &&
          (e.method == ConnectMethod.account ||
              e.authType == 'oauth_device_code'));
  final addable = [
    for (final e in catalog.available)
      if (offered(e)) e,
  ];
  final recommended = <ProviderModelOrder>[];
  final more = <ModelProviderRowData>[];
  for (final e in addable) {
    if (kRecommendedProviderSlugs.contains(e.id)) {
      recommended.add(
        ProviderModelOrder(
          kRecommendedProviderSlugs.indexOf(e.id),
          _offerRow(e),
        ),
      );
    } else {
      more.add(_offerRow(e));
    }
  }
  recommended.sort((a, b) => a.rank.compareTo(b.rank));

  ProviderDefaultModelData? defaultModel;
  if (connected.isNotEmpty && catalog.defaultModel.isNotEmpty) {
    final owner = entryForSlug(catalog, catalog.defaultProvider);
    defaultModel = ProviderDefaultModelData(
      name: catalog.defaultModel,
      providerName: owner?.name ?? catalog.defaultProvider,
    );
  }
  return ProviderListData(
    profile: profile,
    staleOffline: failure == ReadFailure.unreachable,
    restartRequired: failure == ReadFailure.restartRequired,
    defaultModel: defaultModel,
    connected: connected,
    recommended: [for (final r in recommended) r.row],
    more: more,
    endpointOffered: loaded.offered(ProviderSource.endpoints),
    keysFailed: loaded.failed(ProviderSource.env),
    accountsFailed: accountsFailed,
    endpointsFailed: loaded.failed(ProviderSource.endpoints),
  );
}

/// A recommended row with its place in [kRecommendedProviderSlugs].
class ProviderModelOrder {
  const ProviderModelOrder(this.rank, this.row);
  final int rank;
  final ModelProviderRowData row;
}

ProviderApiType _apiTypeOf(String? mode) => switch (mode) {
  'chat_completions' => ProviderApiType.chatCompletions,
  'codex_responses' => ProviderApiType.responses,
  'anthropic_messages' => ProviderApiType.anthropicMessages,
  _ => ProviderApiType.automatic,
};

/// The `api_mode` the server takes for [type]; `''` is "Automatic".
String apiModeOf(ProviderApiType type) => switch (type) {
  ProviderApiType.automatic => '',
  ProviderApiType.chatCompletions => 'chat_completions',
  ProviderApiType.responses => 'codex_responses',
  ProviderApiType.anthropicMessages => 'anthropic_messages',
};

/// An endpoint's saved API type, for the edit form.
ProviderApiType apiTypeOfEntry(ProviderEntry entry) =>
    _apiTypeOf(entry.endpoint?.apiMode);

/// One provider's detail, or null when [entry] is gone.
ProviderDetailData providerDetailData(
  ProviderEntry entry,
  ProviderSetupController controller, {
  required String profile,
}) {
  final keys = entry.credentials
      .where((c) => c.kind == CredentialKind.apiKey)
      .toList();
  final account = entry.account;
  final ProviderStatusKind status;
  if (entry.method == ConnectMethod.endpoint) {
    status = ProviderStatusKind.endpoint;
  } else if (keys.isNotEmpty) {
    status = ProviderStatusKind.key;
  } else if (account != null) {
    status = ProviderStatusKind.signedIn;
  } else if (entry.credentials.any((c) => c.kind == CredentialKind.poolKey)) {
    status = ProviderStatusKind.serverKey;
  } else {
    status = ProviderStatusKind.none;
  }

  final credentials = <ProviderCredentialData>[
    for (final k in keys)
      ProviderCredentialData(
        kind: ProviderCredentialKind.apiKey,
        id: k.keyEnv ?? '',
        lastFour: k.lastFour,
      ),
    if (account != null)
      ProviderCredentialData(
        kind: ProviderCredentialKind.account,
        account: switch (entry.id) {
          'nous' => ProviderAccountLabel.nousPortal,
          'openai-codex' => ProviderAccountLabel.chatGpt,
          _ => ProviderAccountLabel.none,
        },
      ),
    for (final c in entry.credentials)
      if (c.kind == CredentialKind.poolKey)
        ProviderCredentialData(
          kind: ProviderCredentialKind.serverKey,
          lastFour: c.lastFour,
        ),
  ];

  final removals = <ProviderRemovalData>[];
  String? serverCommand;
  String? removalHint;
  for (final action in entry.connected ? removalActionsFor(entry) : const []) {
    switch (action) {
      case RemoveKeyAction(:final keyEnv):
        removals.add(
          ProviderRemovalData(ProviderRemovalKind.removeKey, id: keyEnv),
        );
      case SignOutAction():
        removals.add(const ProviderRemovalData(ProviderRemovalKind.signOut));
      case DeleteEndpointAction():
        removals.add(
          const ProviderRemovalData(ProviderRemovalKind.deleteEndpoint),
        );
      case ServerCommandAction(:final command, :final hint):
        serverCommand = command;
        removalHint = hint;
    }
  }

  final last = controller.lastRemoval;
  final endpoint = entry.endpoint;
  final signIn = controller.signInFor(entry.id);
  return ProviderDetailData(
    name: entry.name,
    profile: profile,
    status: status,
    email: signIn?.accountEmail,
    defaultModel: entry.isDefault && controller.defaultModel.isNotEmpty
        ? ProviderDefaultModelData(
            name: controller.defaultModel,
            providerName: entry.name,
          )
        : null,
    credentials: credentials,
    endpoint: endpoint == null
        ? null
        : ProviderEndpointData(
            address: endpoint.baseUrl,
            apiType: _apiTypeOf(endpoint.apiMode),
            hasKey: endpoint.hasApiKey,
          ),
    models: entry.models,
    modelCount: entry.totalModels > entry.models.length
        ? entry.totalModels
        : entry.models.length,
    removals: removals,
    serverCommand: serverCommand,
    removalHint: removalHint,
    stillConnectedThrough:
        last != null && last.providerId == entry.id && last.stillConnected
        ? last.stillConnectedThrough
        : 0,
  );
}

/// The API key form's data. Texts come from the widget.
ApiKeyFormData apiKeyFormData(
  KeyFormState form,
  ProviderEntry? entry, {
  required String profile,
  required bool keyLinkOpenable,
}) {
  final phase = switch (form.phase) {
    KeyFormPhase.editing || KeyFormPhase.saved => ApiKeyPhase.editing,
    KeyFormPhase.checking => ApiKeyPhase.checking,
    KeyFormPhase.saving => ApiKeyPhase.saving,
    KeyFormPhase.rejected => ApiKeyPhase.rejected,
    KeyFormPhase.providerError => ApiKeyPhase.providerError,
    KeyFormPhase.refused => ApiKeyPhase.refused,
    KeyFormPhase.unknown => ApiKeyPhase.unknown,
  };
  return ApiKeyFormData(
    providerName: entry?.name ?? '',
    profile: profile,
    replacing: form.replacing,
    phase: phase,
    message: form.message == kNotAcceptedMessage ? null : form.message,
    notAccepted:
        phase == ApiKeyPhase.refused && form.message == kNotAcceptedMessage,
    emptyKey: form.emptyKey,
    offersKeyLink: keyLinkOpenable,
    offersAccount: entry?.externalAccount ?? false,
  );
}

/// The sign-in step's data for a sign-in that has not been approved.
SignInCodeData signInCodeData(
  ProviderSignIn signIn,
  String providerName, {
  required String profile,
}) => SignInCodeData(
  providerName: providerName,
  profile: profile,
  phase: switch (signIn.phase) {
    SignInPhase.starting || SignInPhase.waiting => SignInStepPhase.waiting,
    SignInPhase.startRefused => SignInStepPhase.startRefused,
    SignInPhase.startFailed => SignInStepPhase.startFailed,
    SignInPhase.denied => SignInStepPhase.declined,
    SignInPhase.expired => SignInStepPhase.expired,
    SignInPhase.failed ||
    SignInPhase.approved ||
    SignInPhase.cancelled => SignInStepPhase.failed,
  },
  code: signIn.userCode,
  codeInLink: signIn.providerId == 'nous',
  canOpen: signIn.verificationLink != null,
  offline: signIn.offline,
  expiresInMinutes: signIn.lifetimeMinutes,
  message: signIn.message,
);

/// The default-model step's data. [busy] is a save in flight.
DefaultStepData defaultStepData(
  DefaultModelStep step,
  String providerName, {
  required String profile,
}) => DefaultStepData(
  view: switch (step.kind) {
    DefaultStepKind.saved => DefaultStepView.ready,
    DefaultStepKind.ask => DefaultStepView.later,
    DefaultStepKind.choose => DefaultStepView.choose,
    DefaultStepKind.modelsLoading => DefaultStepView.loading,
    // Asking Hermes: the recommendation is shown as it arrives; until then
    // the step reads like the one that follows, with its buttons off.
    DefaultStepKind.preparing => DefaultStepView.ready,
  },
  providerName: providerName,
  profile: profile,
  modelName: step.model,
  currentModelName: step.currentModel,
  note: switch (step.note) {
    null => DefaultStepNote.none,
    KeyNote.unchecked => DefaultStepNote.unchecked,
    KeyNote.unreachable => DefaultStepNote.unreachable,
  },
  failed: step.failed,
  busy: step.kind == DefaultStepKind.preparing,
);

/// The server command page's data.
ServerCommandData serverCommandData(
  ProviderEntry entry, {
  required String profile,
  required bool checking,
}) => ServerCommandData(
  providerName: entry.name,
  profile: profile,
  command: entry.serverCommand ?? 'hermes auth add ${entry.id}',
  checking: checking,
);

/// The picker's options for [entries]: each provider with the models Hermes
/// lists for it, under the slug `model/set` takes. [current] is the profile's
/// default.
ModelOptions modelOptionsOf(
  Iterable<ProviderEntry> entries, {
  ModelChoice? current,
}) => ModelOptions(
  current: current,
  providers: [
    for (final e in entries)
      if (e.models.isNotEmpty)
        ModelProviderOption(
          id: providerSlugOf(e),
          label: e.name,
          models: [for (final id in e.models) ModelOption(id: id)],
        ),
  ],
);

/// The issue of an endpoint form, in the form widget's own terms.
EndpointFormIssue endpointIssueOf(EndpointIssue? issue) => switch (issue) {
  null => EndpointFormIssue.none,
  EndpointIssue.nameMissing => EndpointFormIssue.name,
  EndpointIssue.addressMissing => EndpointFormIssue.address,
  EndpointIssue.addressScheme => EndpointFormIssue.scheme,
  EndpointIssue.modelMissing => EndpointFormIssue.model,
};

/// The endpoint form's data from the controller's [form] and the screen's own
/// choices.
EndpointFormData endpointFormData(
  EndpointFormState form, {
  required String profile,
  required bool editing,
  required String endpointName,
  required bool hasSavedKey,
  required String? selectedModel,
  required ProviderApiType apiType,
  required bool insecureKey,
  required bool offersUseForNew,
  required bool useForNew,
  required String? currentModelName,
}) {
  final EndpointCheck check = switch (form.phase) {
    EndpointFormPhase.checking => EndpointCheck.checking,
    EndpointFormPhase.checked =>
      form.warning != null || form.models.isEmpty
          ? EndpointCheck.noModels
          : EndpointCheck.found,
    EndpointFormPhase.unreachable => EndpointCheck.unreachable,
    EndpointFormPhase.checkFailed => EndpointCheck.failed,
    _ => EndpointCheck.none,
  };
  return EndpointFormData(
    profile: profile,
    editing: editing,
    endpointName: endpointName,
    hasSavedKey: hasSavedKey,
    check: check,
    models: form.models,
    selectedModel: selectedModel,
    resolvedAddress: form.resolvedBaseUrl,
    checkedAddress: form.checkedAddress ?? '',
    warning: form.warning,
    keyNotSent: form.keyNotSent,
    insecureKey: insecureKey,
    apiType: apiType,
    offersUseForNew: offersUseForNew,
    useForNew: useForNew,
    currentModelName: currentModelName,
    saving: form.phase == EndpointFormPhase.saving,
    issue: endpointIssueOf(form.issue),
    refused:
        form.phase == EndpointFormPhase.refused &&
        form.message != kNotAcceptedMessage,
    message: form.message == kNotAcceptedMessage ? null : form.message,
    notAccepted:
        form.phase == EndpointFormPhase.refused &&
        form.message == kNotAcceptedMessage,
    unknown: form.phase == EndpointFormPhase.unknown,
  );
}
