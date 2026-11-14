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

    test('loading, failed and unsupported states show no card', () {
      for (final state in [
        ModelOptionsState.loading,
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

    test('no options yet shows no card', () {
      expect(
        connectCardFor(ModelOptionsState.incomplete, null, profile: 'work'),
        isNull,
      );
    });
  });

  group('isProviderReplyError', () {
    test('recognises a rejected key, no credit and a missing key', () {
      for (final message in [
        'HTTP 401: Incorrect API key provided: test-key-not-real',
        'Error code: 402 - insufficient credits',
        'API call failed: Unauthorized',
        'No API key found for provider example-a',
        'Your account has exceeded its quota',
        'HTTP 403 Forbidden from the provider',
      ]) {
        expect(isProviderReplyError(message), isTrue, reason: message);
      }
    });

    test('leaves other failures alone', () {
      for (final message in [
        'Something went wrong. Try sending it again.',
        'The connection was lost.',
        'Tool terminal failed with exit code 401 lines',
        '',
      ]) {
        expect(isProviderReplyError(message), isFalse, reason: message);
      }
    });
  });
}
