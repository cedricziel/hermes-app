import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/first_run_card.dart';
import 'package:hermes_app/src/models/model_options_state.dart';
import 'package:hermes_app/src/models/model_provider_option.dart';
import 'package:hermes_app/src/providers/widgets/provider_form_models.dart';

const _ready = ModelProviderOption(
  id: 'example-b',
  models: [ModelOption(id: 'example-model-b')],
);
const _lost = ModelChoice('example-a', 'example-model-a');

void main() {
  group('connectCardFor', () {
    test('nothing connected asks to connect a model', () {
      final card = connectCardFor(
        ModelOptionsState.incomplete,
        const ModelOptions(),
        profile: 'work',
      );

      expect(card?.kind, ConnectCardKind.connect);
      expect(card?.profile, 'work');
    });

    test('a connected provider that lists no models is loading', () {
      final card = connectCardFor(
        ModelOptionsState.incomplete,
        const ModelOptions(warming: true),
        profile: 'work',
      );

      expect(card?.kind, ConnectCardKind.loading);
    });

    test('a loading answer that did not change asks to connect instead', () {
      final card = connectCardFor(
        ModelOptionsState.incomplete,
        const ModelOptions(warming: true),
        profile: 'work',
        warmingUnchanged: true,
      );

      expect(card?.kind, ConnectCardKind.connect);
    });

    test('a lost provider asks to reconnect, even when others are ready', () {
      final card = connectCardFor(
        ModelOptionsState.ready,
        const ModelOptions(providers: [_ready], missing: _lost),
        profile: 'work',
      );

      expect(card?.kind, ConnectCardKind.reconnect);
      expect(card?.modelName, 'example-model-a');
      expect(card?.providerId, 'example-a');
    });

    test('a lost provider comes before a warming one', () {
      final card = connectCardFor(
        ModelOptionsState.incomplete,
        const ModelOptions(warming: true, missing: _lost),
        profile: 'work',
      );

      expect(card?.kind, ConnectCardKind.reconnect);
    });

    test('a ready profile shows the starter prompts', () {
      expect(
        connectCardFor(
          ModelOptionsState.ready,
          const ModelOptions(
            providers: [_ready],
            current: ModelChoice('example-b', 'example-model-b'),
          ),
          profile: 'work',
        ),
        isNull,
      );
    });

    test('failed and unsupported states show no card', () {
      for (final state in [
        ModelOptionsState.failed,
        ModelOptionsState.unsupported,
      ]) {
        expect(
          connectCardFor(
            state,
            const ModelOptions(missing: _lost),
            profile: 'work',
          ),
          isNull,
          reason: '$state',
        );
      }
    });

    test('a read in progress keeps the card of the state before it', () {
      final card = connectCardFor(
        ModelOptionsState.loading,
        const ModelOptions(warming: true),
        profile: 'work',
        settled: ModelOptionsState.incomplete,
      );

      expect(card?.kind, ConnectCardKind.loading);
      expect(
        connectCardFor(
          ModelOptionsState.loading,
          const ModelOptions(),
          profile: 'work',
          settled: ModelOptionsState.ready,
        ),
        isNull,
      );
      // The very first read has no earlier state and no options.
      expect(
        connectCardFor(ModelOptionsState.loading, null, profile: 'work'),
        isNull,
      );
    });

    test('no options yet shows no card', () {
      expect(
        connectCardFor(ModelOptionsState.incomplete, null, profile: 'work'),
        isNull,
      );
    });
  });

  group('isProviderReplyError', () {
    test('recognises a status or an explicit key problem', () {
      for (final message in [
        'HTTP 401: Incorrect API key provided: test-key-not-real',
        'Error code: 402 - insufficient credits',
        'HTTP 403 Forbidden from the provider',
        'HTTP 429: too many requests',
        'No API key found for provider example-a',
        'Invalid API key',
        'Missing API key for example-a',
        'The API key is invalid.',
        'Request failed with status code 401',
        "Client error '401 Unauthorized' for url 'https://example.com/v1'",
        '401 Unauthorized',
        // Not a 4xx the list names, but the provider's own billing refusal.
        'Error code: 400 - Your credit balance is too low',
      ]) {
        expect(isProviderReplyError(message), isTrue, reason: message);
      }
    });

    test('leaves other failures alone', () {
      for (final message in [
        'Something went wrong. Try sending it again.',
        'The connection was lost.',
        'Tool terminal failed with exit code 401 lines',
        'MCP server authentication failed',
        'Authentication required for the example tool',
        'Your account has exceeded its quota',
        'Unauthorized',
        'Rotate the api key in the config file',
        'HTTP 500 from the example service',
        // A tool's or a helper model's failure is not the chat model's.
        'Missing API key for Tavily web search',
        'No API key configured for the vision auxiliary model',
        'web_extract failed: HTTP 403 fetching page',
        'The helper model returned HTTP 401',
        '',
      ]) {
        expect(isProviderReplyError(message), isFalse, reason: message);
      }
    });
  });
}
