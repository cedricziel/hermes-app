import 'package:flutter/material.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/providers/widgets/model_provider_row.dart';
import 'package:hermes_app/src/providers/widgets/provider_detail_view.dart';
import 'package:hermes_app/src/providers/widgets/provider_list_view.dart';
import 'package:hermes_app/src/providers/widgets/provider_view_models.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';
import 'provider_form_use_cases.dart';
import 'provider_use_case_helpers.dart';

// ---- invented sample data: neutral model names, example addresses ----

const _openRouter = ModelProviderRowData(
  id: 'openrouter',
  name: 'OpenRouter',
  connection: ProviderConnection.key,
  lastFour: '4f2a',
  isDefault: true,
);

const _nous = ModelProviderRowData(
  id: 'nous',
  name: 'Nous Portal',
  connection: ProviderConnection.signedIn,
  warning: 'Rate limited until 14:20',
);

const _pendingChatGpt = ModelProviderRowData(
  id: 'openai-codex',
  name: 'ChatGPT',
  connection: ProviderConnection.pendingSignIn,
);

const _endpointRow = ModelProviderRowData(
  id: 'custom:gpu-box',
  name: 'My GPU box',
  connection: ProviderConnection.endpoint,
  host: 'gpu-box.example.net',
);

const _defaultModel = ProviderDefaultModelData(
  name: 'Example Model A',
  id: 'example-model-a',
  providerName: 'OpenRouter',
);

ModelProviderRowData _offer(String id, String name, ProviderConnection how) =>
    ModelProviderRowData(id: id, name: name, connection: how);

final _recommended = [
  _offer('nous', 'Nous Portal', ProviderConnection.offerAccount),
  _offer('openrouter', 'OpenRouter', ProviderConnection.offerKey),
  _offer('openai-api', 'OpenAI', ProviderConnection.offerKey),
  _offer('anthropic', 'Anthropic', ProviderConnection.offerKey),
];

final _more = [
  _offer('openai-codex', 'ChatGPT', ProviderConnection.offerAccount),
  _offer('deepseek', 'DeepSeek', ProviderConnection.offerKey),
  _offer('gemini', 'Google AI Studio', ProviderConnection.offerKey),
  _offer('huggingface', 'Hugging Face', ProviderConnection.offerKey),
  _offer('mistral', 'Mistral', ProviderConnection.offerKey),
  _offer('xai', 'xAI', ProviderConnection.offerKey),
  _offer('copilot', 'GitHub Copilot', ProviderConnection.offerOnServer),
];

final _manyMore = [
  ..._more,
  for (final name in [
    'Alpha Models',
    'Beta Cloud',
    'Gamma Inference',
    'Delta AI',
    'Epsilon Hub',
    'Zeta Labs',
    'Eta Compute',
    'Theta Models',
  ])
    _offer(
      name.toLowerCase().replaceAll(' ', '-'),
      name,
      ProviderConnection.offerKey,
    ),
];

ProviderListData _list({
  ProviderListStatus status = ProviderListStatus.loaded,
  List<ModelProviderRowData> connected = const [_openRouter, _nous],
  ProviderDefaultModelData? defaultModel = _defaultModel,
  List<ModelProviderRowData>? recommended,
  List<ModelProviderRowData>? more,
  String? failureReason,
  bool staleOffline = false,
  bool restartRequired = false,
  bool endpointOffered = true,
  bool keysFailed = false,
  bool accountsFailed = false,
  bool endpointsFailed = false,
}) {
  // Nothing is loaded yet while loading, failed or offline with no list.
  final loaded = status == ProviderListStatus.loaded;
  final rows = loaded ? connected : const <ModelProviderRowData>[];
  // A provider that is connected, or waiting for sign-in, leaves "Add a
  // provider".
  List<ModelProviderRowData> addable(List<ModelProviderRowData> list) => [
    for (final r in list)
      if (!rows.any((c) => c.id == r.id)) r,
  ];
  return ProviderListData(
    profile: 'work',
    status: status,
    failureReason: failureReason,
    staleOffline: staleOffline,
    restartRequired: restartRequired,
    defaultModel: rows.isEmpty ? null : defaultModel,
    connected: rows,
    recommended: addable(recommended ?? _recommended),
    more: addable(more ?? _more),
    endpointOffered: endpointOffered,
    keysFailed: keysFailed,
    accountsFailed: accountsFailed,
    endpointsFailed: endpointsFailed,
  );
}

final _models = [
  for (final letter in 'abcdefghijkl'.split('')) 'example-model-$letter',
];

const _openRouterDetail = ProviderDetailData(
  name: 'OpenRouter',
  profile: 'work',
  status: ProviderStatusKind.key,
  defaultModel: _defaultModel,
  credentials: [
    ProviderCredentialData(
      kind: ProviderCredentialKind.apiKey,
      id: 'OPENROUTER_API_KEY',
      lastFour: '4f2a',
    ),
  ],
  models: [
    'example-model-a',
    'example-model-b',
    'example-model-c',
    'example-model-d',
    'example-model-e',
    'example-model-f',
    'example-model-g',
  ],
  modelCount: 7,
  removals: [
    ProviderRemovalData(
      ProviderRemovalKind.removeKey,
      id: 'OPENROUTER_API_KEY',
    ),
  ],
);

ProviderDetailData _openRouterWithModels() => ProviderDetailData(
  name: 'OpenRouter',
  profile: 'work',
  status: ProviderStatusKind.key,
  defaultModel: _defaultModel,
  credentials: _openRouterDetail.credentials,
  models: _models,
  modelCount: _models.length,
  removals: _openRouterDetail.removals,
);

const _nousDetail = ProviderDetailData(
  name: 'Nous Portal',
  profile: 'work',
  status: ProviderStatusKind.signedIn,
  email: 'ada@example.com',
  credentials: [
    ProviderCredentialData(
      kind: ProviderCredentialKind.account,
      account: ProviderAccountLabel.nousPortal,
    ),
  ],
  models: ['example-model-a', 'example-model-b', 'example-model-c'],
  modelCount: 3,
  removals: [ProviderRemovalData(ProviderRemovalKind.signOut)],
);

const _endpointDetail = ProviderDetailData(
  name: 'My GPU box',
  profile: 'work',
  status: ProviderStatusKind.endpoint,
  endpoint: ProviderEndpointData(
    address: 'https://gpu-box.example.net:8000/v1/chat/completions',
    apiType: ProviderApiType.chatCompletions,
    hasKey: true,
  ),
  models: ['example-model-a', 'example-model-b'],
  modelCount: 2,
  removals: [ProviderRemovalData(ProviderRemovalKind.deleteEndpoint)],
);

const _serverKeyDetail = ProviderDetailData(
  name: 'OpenAI',
  profile: 'work',
  status: ProviderStatusKind.serverKey,
  credentials: [
    ProviderCredentialData(
      kind: ProviderCredentialKind.serverKey,
      lastFour: '7890',
    ),
  ],
  models: ['example-model-a', 'example-model-b'],
  modelCount: 2,
);

const _cannotRemoveDetail = ProviderDetailData(
  name: 'ChatGPT',
  profile: 'work',
  status: ProviderStatusKind.signedIn,
  credentials: [
    ProviderCredentialData(
      kind: ProviderCredentialKind.account,
      account: ProviderAccountLabel.chatGpt,
    ),
  ],
  models: ['example-model-a', 'example-model-b'],
  modelCount: 2,
  serverCommand: 'hermes auth remove openai-codex',
);

const _envSignInDetail = ProviderDetailData(
  name: 'Anthropic',
  profile: 'work',
  status: ProviderStatusKind.signedIn,
  credentials: [ProviderCredentialData(kind: ProviderCredentialKind.account)],
  modelCount: 0,
  removals: [
    ProviderRemovalData(ProviderRemovalKind.removeKey, id: 'ANTHROPIC_API_KEY'),
  ],
);

const _stillConnectedDetail = ProviderDetailData(
  name: 'OpenAI',
  profile: 'work',
  status: ProviderStatusKind.serverKey,
  credentials: [
    ProviderCredentialData(
      kind: ProviderCredentialKind.serverKey,
      lastFour: '7890',
    ),
  ],
  modelCount: 0,
  stillConnectedThrough: 1,
);

const _notConnectedDetail = ProviderDetailData(
  name: 'OpenAI',
  profile: 'work',
  status: ProviderStatusKind.none,
);

// ---- layout helpers ----

Widget _listView(
  ProviderListData data, {
  String? selectedId,
  String searchQuery = '',
  ValueChanged<String>? onSearchChanged,
}) => ProviderListView(
  data: data,
  selectedId: selectedId,
  searchQuery: searchQuery,
  onSearchChanged: onSearchChanged,
  onSelect: noopId,
  onAdd: noopId,
  onAddEndpoint: noop,
  onOpenDefaultModel: noop,
  onContinueSignIn: noopId,
  onStopSignIn: noopId,
  onRetry: noop,
  onRetryKeys: noop,
  onRetryAccounts: noop,
  onRetryEndpoints: noop,
);

Widget _listPage(
  ProviderListData data, {
  String? selectedId,
  String searchQuery = '',
  ValueChanged<String>? onSearchChanged,
}) => settingsPage(
  title: (l10n) => l10n.providersListTitle,
  subtitle: (l10n) =>
      providerListSubtitle(l10n, data.profile, data.connectedCount),
  body: _listView(
    data,
    selectedId: selectedId,
    searchQuery: searchQuery,
    onSearchChanged: onSearchChanged,
  ),
);

Widget _detailView(ProviderDetailData data) => ProviderDetailView(
  data: data,
  onChangeDefaultModel: noop,
  onReplaceKey: noopId,
  onRemove: (_) {},
);

Widget _detailPage(ProviderDetailData data) => settingsPage(
  title: (_) => data.name,
  subtitle: (_) => data.profile,
  actions: (l10n) => providerDetailBarActions(l10n, data, onEdit: noop),
  body: _detailView(data),
);

/// A list that filters as the person types.
class _SearchDemo extends StatefulWidget {
  const _SearchDemo({required this.data, this.initialQuery = ''});

  final ProviderListData data;
  final String initialQuery;

  @override
  State<_SearchDemo> createState() => _SearchDemoState();
}

class _SearchDemoState extends State<_SearchDemo> {
  late String _query = widget.initialQuery;

  @override
  Widget build(BuildContext context) => _listPage(
    widget.data,
    searchQuery: _query,
    onSearchChanged: (value) => setState(() => _query = value),
  );
}

/// List beside detail where there is room (the split of a wide window), the
/// list alone, with its selected row, on a phone.
Widget _split(ProviderListData data, ProviderDetailData detail) =>
    LayoutBuilder(
      builder: (context, box) {
        final list = _listPage(data, selectedId: 'openrouter');
        if (box.maxWidth < 800) return list;
        return Row(
          children: [
            SizedBox(width: 360, child: list),
            const VerticalDivider(width: 1),
            Expanded(child: _detailPage(detail)),
          ],
        );
      },
    );

// ---- the use cases ----

WidgetbookUseCase _case(String name, Widget Function(BuildContext) builder) =>
    WidgetbookUseCase(name: name, builder: builder);

WidgetbookComponent _listComponent() => WidgetbookComponent(
  name: 'ProviderListView',
  useCases: [
    ...onEachPlatform(
      'Two connected, one default, a warning',
      (_) => _listPage(_list()),
    ),
    _case('Nothing connected', (_) => _listPage(_list(connected: const []))),
    _case(
      'Loading',
      (_) => _listPage(_list(status: ProviderListStatus.loading)),
    ),
    _case(
      'Partial failure: saved keys',
      (_) => _listPage(
        _list(
          connected: const [
            ModelProviderRowData(
              id: 'openrouter',
              name: 'OpenRouter',
              connection: ProviderConnection.connected,
              isDefault: true,
            ),
            ModelProviderRowData(
              id: 'nous',
              name: 'Nous Portal',
              connection: ProviderConnection.signedIn,
            ),
          ],
          keysFailed: true,
        ),
      ),
    ),
    _case(
      'Partial failure: account sign-in',
      (_) => _listPage(
        _list(
          accountsFailed: true,
          recommended: [
            for (final r in _recommended)
              if (r.connection != ProviderConnection.offerAccount) r,
          ],
          more: [
            for (final r in _more)
              if (r.connection != ProviderConnection.offerAccount) r,
          ],
          connected: const [_openRouter],
        ),
      ),
    ),
    _case(
      'Partial failure: custom endpoints',
      (_) => _listPage(_list(endpointsFailed: true, endpointOffered: false)),
    ),
    _case(
      "Couldn't load",
      (_) => _listPage(_list(status: ProviderListStatus.failed)),
    ),
    _case(
      "Couldn't load, with Hermes' reason",
      (_) => _listPage(
        _list(
          status: ProviderListStatus.failed,
          failureReason: 'The model catalog is still starting.',
        ),
      ),
    ),
    _case(
      'Offline, last list under the banner',
      (_) => _listPage(_list(staleOffline: true)),
    ),
    _case(
      'Offline, nothing loaded',
      (_) => _listPage(_list(status: ProviderListStatus.offline)),
    ),
    _case('Restart required', (_) => _listPage(_list(restartRequired: true))),
    ...onEachPlatform(
      'Sign-in pending',
      (_) => _listPage(_list(connected: const [_openRouter, _pendingChatGpt])),
    ),
    _case(
      'Custom endpoint connected',
      (_) => _listPage(_list(connected: const [_openRouter, _endpointRow])),
    ),
    _case(
      'Section unsupported (no custom endpoints)',
      (_) => _listPage(_list(endpointOffered: false)),
    ),
    _case(
      'Many providers, with search',
      (_) => _SearchDemo(data: _list(more: _manyMore)),
    ),
    _case(
      'Search with no match',
      (_) => _SearchDemo(
        data: _list(more: _manyMore),
        initialQuery: 'zzz',
      ),
    ),
    _case(
      'Selected row, list beside detail',
      (_) => _split(_list(), _openRouterWithModels()),
    ),
    _case(
      'Largest text',
      (_) => scaled(
        3,
        _listPage(
          _list(connected: const [_openRouter, _pendingChatGpt, _nous]),
        ),
      ),
    ),
  ],
);

Widget _rows(List<Widget> rows, {double scale = 1}) =>
    scaled(scale, frame(maxWidth: 420, GroupedSection(children: rows)));

WidgetbookUseCase _rowCase(
  String name,
  ModelProviderRowData row, {
  bool selected = false,
  double scale = 1,
}) => _case(
  name,
  (_) => _rows([
    ModelProviderRow(
      provider: row,
      selected: selected,
      onTap: noop,
      onContinueSignIn: noop,
      onStopSignIn: noop,
    ),
  ], scale: scale),
);

WidgetbookComponent _rowComponent() => WidgetbookComponent(
  name: 'ModelProviderRow',
  useCases: [
    _rowCase(
      'API key ending in 4f2a',
      const ModelProviderRowData(
        id: 'openrouter',
        name: 'OpenRouter',
        connection: ProviderConnection.key,
        lastFour: '4f2a',
      ),
    ),
    _rowCase(
      'API key saved',
      const ModelProviderRowData(
        id: 'openrouter',
        name: 'OpenRouter',
        connection: ProviderConnection.key,
      ),
    ),
    _rowCase(
      'Signed in',
      const ModelProviderRowData(
        id: 'nous',
        name: 'Nous Portal',
        connection: ProviderConnection.signedIn,
      ),
    ),
    _rowCase(
      'Signed in as an email',
      const ModelProviderRowData(
        id: 'nous',
        name: 'Nous Portal',
        connection: ProviderConnection.signedIn,
        email: 'ada@example.com',
      ),
    ),
    _rowCase('Custom endpoint', _endpointRow),
    _rowCase(
      'Connected, how unknown',
      const ModelProviderRowData(
        id: 'openrouter',
        name: 'OpenRouter',
        connection: ProviderConnection.connected,
      ),
    ),
    _rowCase('Default', _openRouter),
    _rowCase('Warning line', _nous),
    _rowCase('Selected', _openRouter, selected: true),
    ...onEachPlatform(
      'Waiting for sign-in',
      (_) => _rows([
        const ModelProviderRow(provider: _pendingChatGpt),
        ModelProviderRow(
          provider: _pendingChatGpt,
          onContinueSignIn: noop,
          onStopSignIn: noop,
        ),
      ]),
    ),
    _case(
      'How each provider connects',
      (context) => _rows([
        for (final r in [
          _offer('openrouter', 'OpenRouter', ProviderConnection.offerKey),
          _offer('nous', 'Nous Portal', ProviderConnection.offerAccount),
          _offer('copilot', 'GitHub Copilot', ProviderConnection.offerOnServer),
          _offer(
            '',
            context.l10n.providersCustomEndpointTitle,
            ProviderConnection.offerEndpoint,
          ),
        ])
          ModelProviderRow(provider: r, onTap: noop),
      ]),
    ),
    _rowCase(
      'Largest text, default with a warning',
      const ModelProviderRowData(
        id: 'openrouter',
        name: 'OpenRouter',
        connection: ProviderConnection.key,
        lastFour: '4f2a',
        isDefault: true,
        warning: 'Rate limited until 14:20',
      ),
      scale: 3,
    ),
    _case(
      'Largest text, waiting for sign-in',
      (_) => _rows([
        ModelProviderRow(
          provider: _pendingChatGpt,
          onContinueSignIn: noop,
          onStopSignIn: noop,
        ),
      ], scale: 3),
    ),
  ],
);

WidgetbookComponent _detailComponent() => WidgetbookComponent(
  name: 'ProviderDetailView',
  useCases: [
    ...onEachPlatform(
      'API key with the default model',
      (_) => _detailPage(_openRouterDetail),
    ),
    _case(
      'API key with many models, Show all',
      (_) => _detailPage(_openRouterWithModels()),
    ),
    _case('Account signed in', (_) => _detailPage(_nousDetail)),
    _case('Custom endpoint', (_) => _detailPage(_endpointDetail)),
    _case(
      'Connected through a key added on the server',
      (_) => _detailPage(_serverKeyDetail),
    ),
    _case(
      "Sign-in Hermes can't remove",
      (_) => _detailPage(_cannotRemoveDetail),
    ),
    _case(
      'Sign-in from an API key variable, Remove key',
      (_) => _detailPage(_envSignInDetail),
    ),
    _case(
      'Still connected after a removal',
      (_) => _detailPage(_stillConnectedDetail),
    ),
    _case('Not connected', (_) => _detailPage(_notConnectedDetail)),
    _case('Largest text', (_) => scaled(3, _detailPage(_openRouterDetail))),
    _case(
      "Largest text, sign-in Hermes can't remove",
      (_) => scaled(3, _detailPage(_cannotRemoveDetail)),
    ),
    _case(
      'Largest text, custom endpoint',
      (_) => scaled(3, _detailPage(_endpointDetail)),
    ),
  ],
);

WidgetbookNode providerSetupNode() => WidgetbookFolder(
  name: 'Model providers',
  children: [
    _listComponent(),
    _rowComponent(),
    _detailComponent(),
    ...providerFormComponents(),
  ],
);
