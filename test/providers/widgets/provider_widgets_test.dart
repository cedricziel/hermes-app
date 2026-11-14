import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/providers/widgets/model_provider_row.dart';
import 'package:hermes_app/src/providers/widgets/provider_detail_view.dart';
import 'package:hermes_app/src/providers/widgets/provider_list_view.dart';
import 'package:hermes_app/src/providers/widgets/provider_view_models.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double scale = 1,
  Locale locale = const Locale('en'),
  TargetPlatform platform = TargetPlatform.iOS,
}) async {
  tester.view
    ..physicalSize = const Size(390, 3000)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildHermesLightTheme().copyWith(platform: platform),
      builder: (context, c) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: c!,
      ),
      home: Scaffold(body: child),
    ),
  );
  await tester.pump(const Duration(seconds: 1));
}

ModelProviderRowData _row(
  ProviderConnection connection, {
  String? lastFour,
  String? email,
  String? host,
  bool isDefault = false,
  String? warning,
}) => ModelProviderRowData(
  id: 'p',
  name: 'OpenRouter',
  connection: connection,
  lastFour: lastFour,
  email: email,
  host: host,
  isDefault: isDefault,
  warning: warning,
);

Widget _inList(Widget row) => GroupedListView(
  children: [
    GroupedSection(children: [row]),
  ],
);

const _pending = ModelProviderRowData(
  id: 'openai-codex',
  name: 'ChatGPT',
  connection: ProviderConnection.pendingSignIn,
);

ProviderListData _data({
  ProviderListStatus status = ProviderListStatus.loaded,
  List<ModelProviderRowData> connected = const [],
  List<ModelProviderRowData> recommended = const [],
  bool endpointOffered = true,
  bool staleOffline = false,
  bool restartRequired = false,
  bool keysFailed = false,
  bool accountsFailed = false,
  bool endpointsFailed = false,
  String? failureReason,
}) => ProviderListData(
  profile: 'work',
  status: status,
  connected: connected,
  recommended: recommended,
  endpointOffered: endpointOffered,
  staleOffline: staleOffline,
  restartRequired: restartRequired,
  keysFailed: keysFailed,
  accountsFailed: accountsFailed,
  endpointsFailed: endpointsFailed,
  failureReason: failureReason,
);

void main() {
  group('ModelProviderRow texts', () {
    Future<void> check(
      WidgetTester tester,
      ModelProviderRowData row,
      String text,
    ) async {
      await _pump(tester, _inList(ModelProviderRow(provider: row)));
      expect(find.text(text), findsOneWidget);
    }

    testWidgets('key ending in four characters', (tester) async {
      await check(
        tester,
        _row(ProviderConnection.key, lastFour: '4f2a'),
        'API key ending in 4f2a',
      );
    });

    testWidgets('key with no characters known', (tester) async {
      await check(tester, _row(ProviderConnection.key), 'API key saved');
    });

    testWidgets('signed in, with and without an email', (tester) async {
      await check(tester, _row(ProviderConnection.signedIn), 'Signed in');
      await check(
        tester,
        _row(ProviderConnection.signedIn, email: 'ada@example.com'),
        'Signed in as ada@example.com',
      );
    });

    testWidgets('custom endpoint with its host', (tester) async {
      await check(
        tester,
        _row(ProviderConnection.endpoint, host: 'gpu-box.example.net'),
        'Custom endpoint · gpu-box.example.net',
      );
    });

    testWidgets('how each addable provider connects', (tester) async {
      await check(tester, _row(ProviderConnection.offerKey), 'API key');
      await check(
        tester,
        _row(ProviderConnection.offerAccount),
        'Sign in with your account',
      );
      await check(
        tester,
        _row(ProviderConnection.offerOnServer),
        'Set up on your server',
      );
      await check(
        tester,
        _row(ProviderConnection.offerEndpoint),
        'vLLM, llama.cpp, Ollama and more',
      );
    });

    testWidgets('Default is a word, and a warning line shows', (tester) async {
      await _pump(
        tester,
        _inList(
          ModelProviderRow(
            provider: _row(
              ProviderConnection.key,
              lastFour: '4f2a',
              isDefault: true,
              warning: 'Rate limited until 14:20',
            ),
          ),
        ),
      );
      expect(
        find.textContaining('Default', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Rate limited until 14:20'), findsOneWidget);
    });

    testWidgets('is read as one sentence, last four spelled out', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        _inList(
          ModelProviderRow(
            provider: _row(
              ProviderConnection.key,
              lastFour: '4f2a',
              isDefault: true,
            ),
            onTap: () {},
          ),
        ),
      );
      expect(
        find.bySemanticsLabel(
          'OpenRouter, API key ending in 4 f 2 a, default model',
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('German', (tester) async {
      await _pump(
        tester,
        _inList(
          ModelProviderRow(
            provider: _row(
              ProviderConnection.key,
              lastFour: '4f2a',
              isDefault: true,
            ),
          ),
        ),
        locale: const Locale('de'),
      );
      expect(find.text('API-Schlüssel, endet auf 4f2a'), findsOneWidget);
      expect(
        find.textContaining('Standard', findRichText: true),
        findsOneWidget,
      );
    });
  });

  group('pending sign-in row', () {
    testWidgets('Stop and Continue, named for the provider, no indicator', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var stopped = 0;
      var continued = 0;
      await _pump(
        tester,
        _inList(
          ModelProviderRow(
            provider: _pending,
            onStopSignIn: () => stopped++,
            onContinueSignIn: () => continued++,
          ),
        ),
      );
      expect(find.text('Waiting for sign-in…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byKey(const Key('grouped-row-chevron')), findsNothing);
      expect(
        find.bySemanticsLabel('Cancel sign-in to ChatGPT'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Continue sign-in to ChatGPT'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextButton, 'Stop'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Continue'), findsOneWidget);
      await tester.tap(find.text('Stop'));
      await tester.tap(find.text('Continue'));
      expect([stopped, continued], [1, 1]);
      handle.dispose();
    });

    testWidgets('buttons are 44 pt on iOS, 48 on Android, 28 on a Mac', (
      tester,
    ) async {
      for (final (platform, height) in [
        (TargetPlatform.iOS, 44.0),
        (TargetPlatform.android, 48.0),
        (TargetPlatform.macOS, 28.0),
      ]) {
        await _pump(
          tester,
          _inList(
            ModelProviderRow(
              provider: _pending,
              onStopSignIn: () {},
              onContinueSignIn: () {},
            ),
          ),
          platform: platform,
        );
        expect(
          tester
              .getSize(find.widgetWithText(OutlinedButton, 'Continue'))
              .height,
          height,
          reason: '$platform',
        );
        expect(
          tester.getSize(find.widgetWithText(TextButton, 'Stop')).height,
          height,
        );
      }
    });

    testWidgets('at the largest text the buttons sit below, Continue first', (
      tester,
    ) async {
      await _pump(
        tester,
        _inList(
          ModelProviderRow(
            provider: _pending,
            onStopSignIn: () {},
            onContinueSignIn: () {},
          ),
        ),
        scale: 3,
      );
      final text = tester.getBottomLeft(find.text('Waiting for sign-in…'));
      final resume = tester.getRect(
        find.widgetWithText(OutlinedButton, 'Continue'),
      );
      final stop = tester.getRect(find.widgetWithText(TextButton, 'Stop'));
      expect(resume.top, greaterThanOrEqualTo(text.dy));
      expect(stop.top, greaterThanOrEqualTo(resume.bottom));
      expect(resume.width, stop.width);
      expect(resume.width, greaterThan(300));
    });
  });

  group('ProviderListView texts', () {
    testWidgets('loading has one label and no empty text', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        ProviderListView(data: _data(status: ProviderListStatus.loading)),
      );
      expect(find.bySemanticsLabel('Loading providers'), findsOneWidget);
      expect(find.text('No model provider yet'), findsNothing);
      handle.dispose();
    });

    testWidgets('nothing connected: message, no button, four recommended', (
      tester,
    ) async {
      await _pump(
        tester,
        ProviderListView(
          data: _data(
            recommended: [
              for (final n in [
                'Nous Portal',
                'OpenRouter',
                'OpenAI',
                'Anthropic',
              ])
                ModelProviderRowData(
                  id: n,
                  name: n,
                  connection: ProviderConnection.offerKey,
                ),
            ],
          ),
        ),
      );
      expect(find.text('No model provider yet'), findsOneWidget);
      expect(
        find.text(
          'Connect one so work can answer. Keys you add here are used by the '
          'work profile only.',
        ),
        findsOneWidget,
      );
      expect(find.byType(FilledButton), findsNothing);
      expect(find.text('Add a provider'), findsOneWidget);
      expect(find.text('Anthropic'), findsOneWidget);
      expect(find.text('Default model'), findsNothing);
    });

    testWidgets('could not load, with Hermes reason or ours', (tester) async {
      await _pump(
        tester,
        ProviderListView(
          data: _data(status: ProviderListStatus.failed),
          onRetry: () {},
        ),
      );
      expect(find.text("Couldn't load providers"), findsOneWidget);
      expect(
        find.text('Something went wrong on your Hermes server.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(FilledButton, 'Try again'), findsOneWidget);
      await _pump(
        tester,
        ProviderListView(
          data: _data(
            status: ProviderListStatus.failed,
            failureReason: 'The catalog is starting.',
          ),
        ),
      );
      expect(find.text('The catalog is starting.'), findsOneWidget);
    });

    testWidgets('offline with nothing loaded and with a list', (tester) async {
      await _pump(
        tester,
        ProviderListView(data: _data(status: ProviderListStatus.offline)),
      );
      expect(find.text("Can't reach your Hermes server"), findsOneWidget);
      expect(
        find.text('Check your connection or VPN, then try again.'),
        findsOneWidget,
      );
      await _pump(
        tester,
        ProviderListView(
          data: _data(
            staleOffline: true,
            connected: [_row(ProviderConnection.key, lastFour: '4f2a')],
          ),
          onRetry: () {},
        ),
      );
      expect(find.text("Can't reach your Hermes server"), findsOneWidget);
      expect(
        find.text(
          'Showing what was last loaded. Check your connection or VPN.',
        ),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('API key ending in 4f2a'), findsOneWidget);
    });

    testWidgets('restart banner', (tester) async {
      await _pump(tester, ProviderListView(data: _data(restartRequired: true)));
      expect(find.text('Your Hermes server needs a restart'), findsOneWidget);
      expect(
        find.text("It was updated. Models can't change until it restarts."),
        findsOneWidget,
      );
    });

    testWidgets('each failed source has its banner with Try again', (
      tester,
    ) async {
      var retried = '';
      await _pump(
        tester,
        ProviderListView(
          data: _data(
            keysFailed: true,
            accountsFailed: true,
            endpointsFailed: true,
          ),
          onRetryKeys: () => retried += 'k',
          onRetryAccounts: () => retried += 'a',
          onRetryEndpoints: () => retried += 'e',
        ),
      );
      expect(
        find.text("Saved keys couldn't be read. You can still add a key."),
        findsOneWidget,
      );
      expect(
        find.text("Account sign-in isn't available right now."),
        findsOneWidget,
      );
      expect(find.text("Custom endpoints couldn't be read."), findsOneWidget);
      expect(find.text('Try again'), findsNWidgets(3));
      for (final button in find.text('Try again').evaluate().toList()) {
        await tester.tap(find.byWidget(button.widget));
      }
      expect(retried.split('')..sort(), ['a', 'e', 'k']);
    });

    testWidgets('an unsupported section is absent without a message', (
      tester,
    ) async {
      await _pump(
        tester,
        ProviderListView(data: _data(endpointOffered: false)),
      );
      expect(find.text('Custom endpoint'), findsNothing);
      expect(find.textContaining("couldn't be read"), findsNothing);
    });

    testWidgets('the subtitle counts connected providers, not pending', (
      tester,
    ) async {
      await _pump(tester, const SizedBox());
      final l10n = AppLocalizations.of(
        tester.element(find.byType(SizedBox).first),
      );
      final data = _data(connected: [_row(ProviderConnection.key), _pending]);
      expect(
        providerListSubtitle(l10n, 'work', data.connectedCount),
        'work · 1 connected',
      );
      expect(providerListSubtitle(l10n, 'work', 0), 'work');
    });

    testWidgets('tapping rows reports their id', (tester) async {
      final seen = <String>[];
      await _pump(
        tester,
        ProviderListView(
          data: _data(
            connected: [_row(ProviderConnection.key, lastFour: '4f2a')],
            recommended: [
              const ModelProviderRowData(
                id: 'anthropic',
                name: 'Anthropic',
                connection: ProviderConnection.offerKey,
              ),
            ],
          ),
          onSelect: (id) => seen.add('select $id'),
          onAdd: (id) => seen.add('add $id'),
        ),
      );
      await tester.tap(find.text('API key ending in 4f2a'));
      await tester.tap(find.text('Anthropic'));
      expect(seen, ['select p', 'add anthropic']);
    });
  });

  group('ProviderDetailView', () {
    const key = ProviderCredentialData(
      kind: ProviderCredentialKind.apiKey,
      id: 'OPENROUTER_API_KEY',
      lastFour: '4f2a',
    );

    testWidgets('API key with the default model', (tester) async {
      String? replaced;
      ProviderRemovalData? removed;
      await _pump(
        tester,
        ProviderDetailView(
          data: const ProviderDetailData(
            name: 'OpenRouter',
            profile: 'work',
            status: ProviderStatusKind.key,
            defaultModel: ProviderDefaultModelData(
              name: 'Example Model A',
              id: 'example-model-a',
              providerName: 'OpenRouter',
            ),
            credentials: [key],
            removals: [
              ProviderRemovalData(
                ProviderRemovalKind.removeKey,
                id: 'OPENROUTER_API_KEY',
              ),
            ],
          ),
          onReplaceKey: (id) => replaced = id,
          onRemove: (r) => removed = r,
        ),
      );
      expect(
        find.textContaining('Connected with an API key', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('New chats in work use this model.'), findsOneWidget);
      expect(find.text('Change'), findsOneWidget);
      expect(find.text('API key ending in 4f2a'), findsOneWidget);
      await tester.tap(find.text('Replace key'));
      expect(replaced, 'OPENROUTER_API_KEY');
      await tester.tap(find.text('Remove key'));
      expect(removed?.kind, ProviderRemovalKind.removeKey);
      // A removal is red text on a plain row, never a filled button.
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('signed in as an email', (tester) async {
      await _pump(
        tester,
        const ProviderDetailView(
          data: ProviderDetailData(
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
            removals: [ProviderRemovalData(ProviderRemovalKind.signOut)],
          ),
        ),
      );
      expect(
        find.textContaining('Signed in as ada@example.com', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Nous Portal account'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
    });

    testWidgets('custom endpoint: address, API type, key, Edit in the bar', (
      tester,
    ) async {
      const data = ProviderDetailData(
        name: 'My GPU box',
        profile: 'work',
        status: ProviderStatusKind.endpoint,
        endpoint: ProviderEndpointData(
          address: 'https://gpu-box.example.net/v1',
          apiType: ProviderApiType.chatCompletions,
          hasKey: true,
        ),
        removals: [ProviderRemovalData(ProviderRemovalKind.deleteEndpoint)],
      );
      await _pump(tester, const ProviderDetailView(data: data));
      expect(
        find.textContaining('Custom endpoint', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('https://gpu-box.example.net/v1'), findsOneWidget);
      expect(find.text('Chat Completions'), findsOneWidget);
      expect(find.text('Saved'), findsOneWidget);
      expect(find.text('Delete endpoint'), findsOneWidget);
      final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)));
      final actions = providerDetailBarActions(l10n, data, onEdit: () {});
      expect(actions.single.label, 'Edit');
      expect(
        providerDetailBarActions(
          l10n,
          const ProviderDetailData(
            name: 'x',
            profile: 'work',
            status: ProviderStatusKind.key,
          ),
          onEdit: () {},
        ),
        isEmpty,
      );
    });

    testWidgets('a key added on the server is read-only, no removal', (
      tester,
    ) async {
      await _pump(
        tester,
        const ProviderDetailView(
          data: ProviderDetailData(
            name: 'OpenAI',
            profile: 'work',
            status: ProviderStatusKind.serverKey,
            credentials: [
              ProviderCredentialData(
                kind: ProviderCredentialKind.serverKey,
                lastFour: '7890',
              ),
            ],
            stillConnectedThrough: 1,
          ),
        ),
      );
      expect(find.text('Saved key ending in 7890'), findsOneWidget);
      expect(find.text('Added on the server'), findsOneWidget);
      expect(
        find.text('Manage this key on your server with hermes auth.'),
        findsOneWidget,
      );
      expect(
        find.text('Still connected through 1 other saved credential.'),
        findsOneWidget,
      );
      expect(find.text('Replace key'), findsNothing);
      expect(find.text('Remove key'), findsNothing);
      expect(find.text('Sign out'), findsNothing);
    });

    testWidgets('a sign-in Hermes cannot remove shows the command', (
      tester,
    ) async {
      await _pump(
        tester,
        const ProviderDetailView(
          data: ProviderDetailData(
            name: 'ChatGPT',
            profile: 'work',
            status: ProviderStatusKind.signedIn,
            credentials: [
              ProviderCredentialData(kind: ProviderCredentialKind.account),
            ],
            serverCommand: 'hermes auth remove openai-codex',
          ),
        ),
      );
      expect(
        find.text(
          "Hermes can't remove this sign-in from the app. Run this on your server:",
        ),
        findsOneWidget,
      );
      expect(find.text('hermes auth remove openai-codex'), findsOneWidget);
      expect(find.text('Sign out'), findsNothing);
    });

    testWidgets('models show five, then all', (tester) async {
      await _pump(
        tester,
        ProviderDetailView(
          data: ProviderDetailData(
            name: 'OpenRouter',
            profile: 'work',
            status: ProviderStatusKind.key,
            models: [for (var i = 0; i < 12; i++) 'example-model-$i'],
            modelCount: 12,
          ),
        ),
      );
      expect(find.text('12 MODELS'), findsOneWidget);
      expect(find.text('example-model-4'), findsOneWidget);
      expect(find.text('example-model-5'), findsNothing);
      await tester.tap(find.text('Show all 12'));
      await tester.pump();
      expect(find.text('example-model-11'), findsOneWidget);
      expect(find.text('Show fewer'), findsOneWidget);
    });

    testWidgets('at the largest text Replace key sits below, full width', (
      tester,
    ) async {
      await _pump(
        tester,
        const ProviderDetailView(
          data: ProviderDetailData(
            name: 'OpenRouter',
            profile: 'work',
            status: ProviderStatusKind.key,
            credentials: [key],
          ),
        ),
        scale: 3,
      );
      final text = tester.getBottomLeft(find.text('API key ending in 4f2a'));
      final button = tester.getRect(find.text('Replace key'));
      expect(button.top, greaterThanOrEqualTo(text.dy));
      expect(
        tester
            .getSize(find.widgetWithText(OutlinedButton, 'Replace key'))
            .width,
        greaterThan(300),
      );
    });

    testWidgets('German', (tester) async {
      await _pump(
        tester,
        const ProviderDetailView(
          data: ProviderDetailData(
            name: 'OpenRouter',
            profile: 'work',
            status: ProviderStatusKind.key,
            credentials: [key],
            removals: [
              ProviderRemovalData(ProviderRemovalKind.removeKey, id: 'k'),
            ],
          ),
        ),
        locale: const Locale('de'),
      );
      expect(
        find.textContaining(
          'Mit einem API-Schlüssel verbunden',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(find.text('Schlüssel ersetzen'), findsOneWidget);
      expect(find.text('Schlüssel entfernen'), findsOneWidget);
    });
  });
  group('search', () {
    List<ModelProviderRowData> offers(int n) => [
      for (var i = 0; i < n; i++)
        ModelProviderRowData(
          id: 'p$i',
          name: 'Provider ${String.fromCharCode(65 + i)}',
          connection: ProviderConnection.offerKey,
        ),
    ];
    ProviderListData data(int n) => ProviderListData(
      profile: 'work',
      more: offers(n),
      endpointOffered: false,
    );
    const field = Key('settings-search-field');

    testWidgets('shows only above twelve entries', (tester) async {
      await _pump(
        tester,
        ProviderListView(data: data(12), onSearchChanged: (_) {}),
      );
      expect(find.byKey(field), findsNothing);
      await _pump(
        tester,
        ProviderListView(data: data(13), onSearchChanged: (_) {}),
      );
      expect(find.byKey(field), findsOneWidget);
      expect(find.text('Search providers'), findsOneWidget);
    });

    testWidgets('counts the custom endpoint entry', (tester) async {
      await _pump(
        tester,
        ProviderListView(
          data: ProviderListData(profile: 'work', more: offers(12)),
          onSearchChanged: (_) {},
        ),
      );
      expect(find.byKey(field), findsOneWidget);
    });

    testWidgets('filters by name and says when nothing matches', (
      tester,
    ) async {
      await _pump(
        tester,
        ProviderListView(
          data: data(13),
          searchQuery: 'provider c',
          onSearchChanged: (_) {},
        ),
      );
      expect(find.text('Provider C'), findsOneWidget);
      expect(find.text('Provider D'), findsNothing);
      await _pump(
        tester,
        ProviderListView(
          data: data(13),
          searchQuery: 'zzz',
          onSearchChanged: (_) {},
        ),
      );
      expect(find.text('No provider matches your search.'), findsOneWidget);
      expect(find.text('Provider C'), findsNothing);
    });

    testWidgets('typing reports the query', (tester) async {
      String? query;
      await _pump(
        tester,
        ProviderListView(data: data(13), onSearchChanged: (q) => query = q),
      );
      await tester.enterText(find.byKey(field), 'prov');
      expect(query, 'prov');
    });

    testWidgets('is left to the toolbar on a Mac, which still filters', (
      tester,
    ) async {
      await _pump(
        tester,
        ProviderListView(
          data: data(13),
          searchQuery: 'provider c',
          onSearchChanged: (_) {},
        ),
        platform: TargetPlatform.macOS,
      );
      expect(find.byKey(field), findsNothing);
      expect(find.text('Provider C'), findsOneWidget);
      expect(find.text('Provider D'), findsNothing);
    });
  });

  group('accessibility', () {
    testWidgets('Replace key names the provider, the key is spelled out', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        ProviderDetailView(
          data: const ProviderDetailData(
            name: 'OpenRouter',
            profile: 'work',
            status: ProviderStatusKind.key,
            credentials: [
              ProviderCredentialData(
                kind: ProviderCredentialKind.apiKey,
                id: 'K',
                lastFour: '4f2a',
              ),
            ],
          ),
          onReplaceKey: (_) {},
        ),
      );
      expect(
        find.bySemanticsLabel('Replace key for OpenRouter'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('API key ending in 4 f 2 a'),
        findsOneWidget,
      );
      handle.dispose();
    });

    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      testWidgets('buttons are named and big enough on $platform', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await _pump(
          tester,
          Column(
            children: [
              Expanded(
                child: ProviderDetailView(
                  data: const ProviderDetailData(
                    name: 'OpenRouter',
                    profile: 'work',
                    status: ProviderStatusKind.key,
                    credentials: [
                      ProviderCredentialData(
                        kind: ProviderCredentialKind.apiKey,
                        id: 'K',
                        lastFour: '4f2a',
                      ),
                    ],
                    removals: [
                      ProviderRemovalData(ProviderRemovalKind.removeKey),
                    ],
                  ),
                  onReplaceKey: (_) {},
                  onRemove: (_) {},
                ),
              ),
              SizedBox(
                height: 200,
                child: ModelProviderRow(
                  provider: _pending,
                  onStopSignIn: () {},
                  onContinueSignIn: () {},
                ),
              ),
            ],
          ),
          platform: platform,
        );
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(
          tester,
          meetsGuideline(
            platform == TargetPlatform.iOS
                ? iOSTapTargetGuideline
                : androidTapTargetGuideline,
          ),
        );
        handle.dispose();
      });
    }

    testWidgets('a selected row has no chevron', (tester) async {
      await _pump(
        tester,
        _inList(
          ModelProviderRow(
            provider: _row(ProviderConnection.key, lastFour: '4f2a'),
            selected: true,
            onTap: () {},
          ),
        ),
      );
      expect(find.byKey(const Key('grouped-row-chevron')), findsNothing);
    });
  });
}
