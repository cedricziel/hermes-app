import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/models/model_provider_option.dart';

void main() {
  group('ModelOption.displayLabel', () {
    test('falls back to id when label is empty', () {
      expect(const ModelOption(id: 'gpt-5.1').displayLabel, 'gpt-5.1');
    });

    test('prefers label when set', () {
      expect(
        const ModelOption(id: 'gpt-5.1', label: 'GPT-5.1').displayLabel,
        'GPT-5.1',
      );
    });
  });

  group('ModelProviderOption', () {
    test('displayLabel falls back to id when label is empty', () {
      expect(const ModelProviderOption(id: 'openai').displayLabel, 'openai');
    });

    test('ready reflects status', () {
      expect(
        const ModelProviderOption(
          id: 'openai',
          status: ModelProviderStatus.ready,
        ).ready,
        isTrue,
      );
      expect(
        const ModelProviderOption(
          id: 'openai',
          status: ModelProviderStatus.needsSetup,
        ).ready,
        isFalse,
      );
    });
  });
}
