import 'package:flutter/cupertino.dart' show CupertinoDialogAction;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/providers/widgets/api_key_form.dart';
import 'package:hermes_app/src/providers/widgets/connect_model_card.dart';
import 'package:hermes_app/src/providers/widgets/default_model_step.dart';
import 'package:hermes_app/src/providers/widgets/endpoint_form.dart';
import 'package:hermes_app/src/providers/widgets/provider_alerts.dart';
import 'package:hermes_app/src/providers/widgets/provider_form_models.dart';
import 'package:hermes_app/src/providers/widgets/server_command_view.dart';
import 'package:hermes_app/src/providers/widgets/sign_in_code_view.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

const _fakeKey = 'test-key-not-real';

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

ApiKeyFormData _key(
  ApiKeyPhase phase, {
  String? message,
  bool notAccepted = false,
  bool emptyKey = false,
  bool keyLink = true,
  bool account = false,
}) => ApiKeyFormData(
  providerName: 'OpenRouter',
  profile: 'work',
  phase: phase,
  message: message,
  notAccepted: notAccepted,
  emptyKey: emptyKey,
  offersKeyLink: keyLink,
  offersAccount: account,
);

EditableText _editable(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText).first);

void main() {
  group('ApiKeyForm', () {
    late TextEditingController controller;
    setUp(() => controller = TextEditingController());
    tearDown(() => controller.dispose());

    Future<void> pumpForm(
      WidgetTester tester,
      ApiKeyFormData data, {
      List<String>? log,
      bool shown = false,
      int focusRequest = 0,
      Locale locale = const Locale('en'),
    }) => _pump(
      tester,
      ApiKeyForm(
        data: data,
        controller: controller,
        initiallyShown: shown,
        focusRequest: focusRequest,
        onSave: (t) => log?.add('save:$t'),
        onSaveAnyway: (t) => log?.add('anyway:$t'),
        onTryAgain: (t) => log?.add('again:$t'),
        onEditKey: () => log?.add('edit'),
      ),
      locale: locale,
    );

    testWidgets('empty: the field, its note and the key link', (tester) async {
      await pumpForm(tester, _key(ApiKeyPhase.editing));
      expect(find.text('API key'), findsOneWidget);
      expect(find.text('Paste your key'), findsOneWidget);
      expect(
        find.text(
          "Saved on your Hermes server for work. You won't see it again here.",
        ),
        findsOneWidget,
      );
      expect(find.text('Get a key from OpenRouter'), findsOneWidget);
      expect(find.textContaining('character'), findsNothing);
      expect(_editable(tester).obscureText, isTrue);
    });

    testWidgets('no key link unless Hermes gave a safe address', (
      tester,
    ) async {
      await pumpForm(tester, _key(ApiKeyPhase.editing, keyLink: false));
      expect(find.text('Get a key from OpenRouter'), findsNothing);
    });

    testWidgets('titles and the bar action', (tester) async {
      await pumpForm(tester, _key(ApiKeyPhase.editing));
      final l10n = AppLocalizations.of(tester.element(find.byType(ApiKeyForm)));
      expect(
        apiKeyFormTitle(l10n, _key(ApiKeyPhase.editing)),
        'Connect OpenRouter',
      );
      const replacing = ApiKeyFormData(
        providerName: 'OpenRouter',
        profile: 'work',
        replacing: true,
      );
      expect(apiKeyFormTitle(l10n, replacing), 'Replace key');
      // Save waits for text, is a spinner while busy, and is gone after a
      // rejection or a provider error.
      expect(
        apiKeyFormAction(
          l10n,
          _key(ApiKeyPhase.editing),
          hasText: false,
        )?.onPressed,
        isNull,
      );
      expect(
        apiKeyFormAction(
          l10n,
          _key(ApiKeyPhase.editing),
          hasText: true,
          onSave: () {},
        )?.onPressed,
        isNotNull,
      );
      expect(
        apiKeyFormAction(l10n, _key(ApiKeyPhase.checking), hasText: true)?.busy,
        isTrue,
      );
      expect(
        apiKeyFormAction(l10n, _key(ApiKeyPhase.rejected), hasText: true),
        isNull,
      );
      expect(
        apiKeyFormAction(l10n, _key(ApiKeyPhase.providerError), hasText: true),
        isNull,
      );
    });

    testWidgets('the account link shows only when offered', (tester) async {
      await pumpForm(tester, _key(ApiKeyPhase.editing, account: true));
      expect(find.text('Use an OpenRouter account instead'), findsOneWidget);
    });

    testWidgets('says how many characters were typed', (tester) async {
      controller.text = _fakeKey;
      await pumpForm(tester, _key(ApiKeyPhase.editing));
      expect(find.text('17 characters entered'), findsOneWidget);
    });

    testWidgets('empty save: Paste the key first', (tester) async {
      await pumpForm(tester, _key(ApiKeyPhase.editing, emptyKey: true));
      expect(find.text('Paste the key first'), findsOneWidget);
    });

    testWidgets('checking and saving say so, and hide a shown key', (
      tester,
    ) async {
      controller.text = _fakeKey;
      await pumpForm(tester, _key(ApiKeyPhase.editing), shown: true);
      expect(_editable(tester).obscureText, isFalse);
      await pumpForm(tester, _key(ApiKeyPhase.checking), shown: true);
      expect(find.text('Checking key…'), findsOneWidget);
      expect(_editable(tester).obscureText, isTrue);
      expect(
        _editable(tester).readOnly ||
            !tester.widget<TextField>(find.byType(TextField)).enabled!,
        isTrue,
      );
      await pumpForm(tester, _key(ApiKeyPhase.saving));
      expect(find.text('Saving…'), findsOneWidget);
    });

    testWidgets('a shown key is hidden once a save failed, text kept', (
      tester,
    ) async {
      controller.text = _fakeKey;
      await pumpForm(tester, _key(ApiKeyPhase.editing), shown: true);
      expect(_editable(tester).obscureText, isFalse);
      await pumpForm(
        tester,
        _key(ApiKeyPhase.refused, message: 'This key is managed.'),
        shown: true,
      );
      expect(_editable(tester).obscureText, isTrue);
      expect(controller.text, _fakeKey);
      expect(find.text('This key is managed.'), findsOneWidget);
    });

    testWidgets('a plain failure keeps the typed key', (tester) async {
      controller.text = _fakeKey;
      // The key is shown first, then the check starts and the answer fails.
      await pumpForm(tester, _key(ApiKeyPhase.editing), shown: true);
      expect(_editable(tester).obscureText, isFalse);
      await pumpForm(tester, _key(ApiKeyPhase.checking), shown: true);
      await pumpForm(
        tester,
        _key(
          ApiKeyPhase.rejected,
          message: 'That API key was rejected. Double-check it and try again.',
        ),
        shown: true,
      );
      await tester.pump();
      expect(controller.text, _fakeKey);
      expect(_editable(tester).obscureText, isTrue);
    });

    testWidgets('a lost answer clears the field and says so', (tester) async {
      controller.text = _fakeKey;
      await pumpForm(tester, _key(ApiKeyPhase.saving));
      await pumpForm(tester, _key(ApiKeyPhase.unknown));
      await tester.pump();
      expect(controller.text, isEmpty);
      expect(
        find.text("Couldn't tell whether the key was saved"),
        findsOneWidget,
      );
      expect(find.text('Paste it again to be sure.'), findsOneWidget);
      expect(find.textContaining('character'), findsNothing);
    });

    testWidgets('the form never restores a key: no restoration id', (
      tester,
    ) async {
      await pumpForm(tester, _key(ApiKeyPhase.editing));
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.restorationId, isNull);
      expect(field.autocorrect, isFalse);
      expect(field.enableSuggestions, isFalse);
      expect(field.autofillHints, isNull);
    });

    testWidgets('rejected: Edit key is primary, Save anyway sends the key', (
      tester,
    ) async {
      final log = <String>[];
      controller.text = _fakeKey;
      await pumpForm(
        tester,
        _key(ApiKeyPhase.rejected, message: 'Rejected.'),
        log: log,
      );
      expect(find.text('Edit key'), findsOneWidget);
      expect(find.text('Save anyway'), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(FilledButton),
          matching: find.text('Edit key'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Save anyway'));
      await tester.tap(find.text('Edit key'));
      expect(log, ['anyway:$_fakeKey', 'edit']);
    });

    testWidgets('provider error: Save anyway is primary, Try again outlined', (
      tester,
    ) async {
      final log = <String>[];
      controller.text = _fakeKey;
      await pumpForm(
        tester,
        _key(
          ApiKeyPhase.providerError,
          message: 'Provider returned HTTP 503 for this key.',
        ),
        log: log,
      );
      expect(find.text("OpenRouter didn't answer normally"), findsOneWidget);
      expect(
        find.text('Provider returned HTTP 503 for this key.'),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(FilledButton),
          matching: find.text('Save anyway'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Try again'));
      expect(log, ['again:$_fakeKey']);
    });

    testWidgets('422 shows the fixed sentence', (tester) async {
      await pumpForm(tester, _key(ApiKeyPhase.refused, notAccepted: true));
      expect(find.text("Hermes didn't accept the request"), findsOneWidget);
    });

    testWidgets('Return does the primary action', (tester) async {
      final log = <String>[];
      await pumpForm(tester, _key(ApiKeyPhase.editing), log: log);
      await tester.enterText(find.byType(EditableText), _fakeKey);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      expect(log, ['save:$_fakeKey']);
    });

    testWidgets('German', (tester) async {
      await pumpForm(
        tester,
        _key(ApiKeyPhase.rejected, message: 'x'),
        locale: const Locale('de'),
      );
      expect(find.text('Schlüssel bearbeiten'), findsOneWidget);
      expect(find.text('Trotzdem speichern'), findsOneWidget);
      expect(find.text('API-Schlüssel'), findsOneWidget);
    });

    testWidgets('the largest text size does not overflow', (tester) async {
      controller.text = _fakeKey;
      await pumpForm(tester, _key(ApiKeyPhase.rejected, message: 'Rejected.'));
      await _pump(
        tester,
        ApiKeyForm(
          data: _key(ApiKeyPhase.rejected, message: 'Rejected.'),
          controller: controller,
        ),
        scale: 3,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('SignInCodeView', () {
    SignInCodeData data({
      SignInStepPhase phase = SignInStepPhase.waiting,
      String? code = 'WDJB-MJHT',
      bool codeInLink = false,
      bool canOpen = true,
      bool offline = false,
      String? message,
    }) => SignInCodeData(
      providerName: 'ChatGPT',
      profile: 'work',
      phase: phase,
      code: code,
      codeInLink: codeInLink,
      canOpen: canOpen,
      offline: offline,
      expiresInMinutes: 14,
      message: message,
    );

    testWidgets('waiting: steps, code, status, lifetime and profile', (
      tester,
    ) async {
      await _pump(tester, SignInCodeView(data: data()));
      expect(find.text('1. Open ChatGPT and sign in.'), findsOneWidget);
      expect(find.text('Open ChatGPT'), findsOneWidget);
      expect(find.text('2. Enter this code if asked:'), findsOneWidget);
      expect(find.text('WDJB-'), findsOneWidget);
      expect(find.text('MJHT'), findsOneWidget);
      expect(find.text('Copy code'), findsOneWidget);
      expect(find.text('Waiting for you to approve…'), findsOneWidget);
      expect(find.text('The code expires in 14 minutes.'), findsOneWidget);
      expect(
        find.text('Signs work in. Other profiles stay as they are.'),
        findsOneWidget,
      );
    });

    testWidgets('Nous: the link carries the code', (tester) async {
      await _pump(tester, SignInCodeView(data: data(codeInLink: true)));
      expect(find.text('Check that this code matches:'), findsOneWidget);
      expect(find.text('2. Enter this code if asked:'), findsNothing);
    });

    testWidgets("can't reach the server keeps the code", (tester) async {
      await _pump(tester, SignInCodeView(data: data(offline: true)));
      expect(
        find.text("Can't reach your server. Still waiting…"),
        findsOneWidget,
      );
      expect(find.text('WDJB-'), findsOneWidget);
    });

    testWidgets('no Open button for an unsafe address, code still shown', (
      tester,
    ) async {
      await _pump(tester, SignInCodeView(data: data(canOpen: false)));
      expect(find.text('Open ChatGPT'), findsNothing);
      expect(find.text('MJHT'), findsOneWidget);
    });

    testWidgets('Copy code copies, says Copied for two seconds', (
      tester,
    ) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      var announced = 0;
      await _pump(
        tester,
        SignInCodeView(data: data(), onCopied: () => announced++),
      );
      await tester.tap(find.text('Copy code'));
      await tester.pump();
      expect(copied, 'WDJB-MJHT');
      expect(find.text('Copied'), findsOneWidget);
      expect(announced, 1);
      await tester.pump(const Duration(seconds: 2, milliseconds: 100));
      expect(find.text('Copy code'), findsOneWidget);
    });

    testWidgets('the code is read character by character, by group', (
      tester,
    ) async {
      expect(spokenSignInCode('WDJB-MJHT'), 'W D J B, M J H T');
      final handle = tester.ensureSemantics();
      await _pump(tester, SignInCodeView(data: data()));
      expect(
        find.bySemanticsLabel('Sign-in code: W D J B, M J H T'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('end states: one message and one button', (tester) async {
      var again = 0;
      await _pump(
        tester,
        SignInCodeView(
          data: data(phase: SignInStepPhase.declined, code: null),
          onStartAgain: () => again++,
        ),
      );
      expect(find.text('The sign-in was declined.'), findsOneWidget);
      expect(find.text('WDJB-'), findsNothing);
      await tester.tap(find.text('Start again'));
      expect(again, 1);

      await _pump(
        tester,
        SignInCodeView(data: data(phase: SignInStepPhase.expired, code: null)),
      );
      expect(find.text('The code expired.'), findsOneWidget);

      await _pump(
        tester,
        SignInCodeView(
          data: data(
            phase: SignInStepPhase.failed,
            code: null,
            message: 'Not accepting sign-ins.',
          ),
        ),
      );
      expect(find.text('Sign-in failed.'), findsOneWidget);
      expect(find.text('Not accepting sign-ins.'), findsOneWidget);

      await _pump(
        tester,
        SignInCodeView(data: data(phase: SignInStepPhase.failed, code: null)),
      );
      expect(find.text('Sign-in failed.'), findsOneWidget);
    });

    testWidgets('start refused: Hermes sentence and Check again, no code', (
      tester,
    ) async {
      var checks = 0;
      await _pump(
        tester,
        SignInCodeView(
          data: data(
            phase: SignInStepPhase.startRefused,
            code: null,
            message: 'Nous Portal is already signed in.',
          ),
          onCheckAgain: () => checks++,
        ),
      );
      expect(find.text('Nous Portal is already signed in.'), findsOneWidget);
      await tester.tap(find.text('Check again'));
      expect(checks, 1);
      expect(find.text('Copy code'), findsNothing);
    });

    testWidgets('largest text wraps the code and does not overflow', (
      tester,
    ) async {
      await _pump(tester, SignInCodeView(data: data()), scale: 3);
      expect(tester.takeException(), isNull);
      expect(find.text('WDJB-'), findsOneWidget);
    });
  });

  group('status lines for a busy step and a check', () {
    testWidgets('the default-model step says Saving… while busy', (
      tester,
    ) async {
      await _pump(
        tester,
        const DefaultModelStep(
          data: DefaultStepData(
            view: DefaultStepView.ready,
            providerName: 'OpenRouter',
            profile: 'work',
            modelName: 'Example Model A',
            busy: true,
          ),
        ),
      );
      expect(find.text('Saving…'), findsOneWidget);
    });

    testWidgets('the server command page says Checking… in German too', (
      tester,
    ) async {
      const data = ServerCommandData(
        providerName: 'Anthropic',
        profile: 'work',
        command: 'hermes auth add anthropic',
        checking: true,
      );
      await _pump(tester, const ServerCommandView(data: data));
      expect(find.text('Checking…'), findsOneWidget);
      await _pump(
        tester,
        const ServerCommandView(data: data),
        locale: const Locale('de'),
      );
      expect(find.text('Wird geprüft …'), findsOneWidget);
    });

    testWidgets('a code with spaces is shown without trailing spaces', (
      tester,
    ) async {
      await _pump(
        tester,
        const SignInCodeView(
          data: SignInCodeData(
            providerName: 'ChatGPT',
            profile: 'work',
            code: 'WDJB MJHT',
          ),
        ),
      );
      expect(find.text('WDJB'), findsOneWidget);
      expect(find.text('MJHT'), findsOneWidget);
    });
  });

  group('ServerCommandView', () {
    testWidgets('heading, command, Check again and Done', (tester) async {
      var checked = 0;
      await _pump(
        tester,
        ServerCommandView(
          data: const ServerCommandData(
            providerName: 'Anthropic',
            profile: 'work',
            command: 'hermes auth add anthropic',
          ),
          onCheckAgain: () => checked++,
        ),
      );
      expect(find.text('Connect Anthropic on your server'), findsOneWidget);
      expect(find.text('hermes auth add anthropic'), findsOneWidget);
      expect(find.text('Applies to the work profile only.'), findsOneWidget);
      await tester.tap(find.text('Check again'));
      expect(checked, 1);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(ServerCommandView)),
      );
      expect(serverCommandFormAction(l10n).label, 'Done');
    });
  });

  group('EndpointForm', () {
    late TextEditingController name, address, key, model;
    setUp(() {
      name = TextEditingController(text: 'My GPU box');
      address = TextEditingController(text: 'https://gpu-box.example.net');
      key = TextEditingController();
      model = TextEditingController();
    });
    tearDown(() {
      for (final c in [name, address, key, model]) {
        c.dispose();
      }
    });

    Future<void> pumpForm(
      WidgetTester tester,
      EndpointFormData data, {
      Locale locale = const Locale('en'),
      VoidCallback? onCheck,
      VoidCallback? onRemoveSavedKey,
    }) => _pump(
      tester,
      EndpointForm(
        data: data,
        nameController: name,
        addressController: address,
        keyController: key,
        modelController: model,
        onCheck: onCheck,
        onRemoveSavedKey: onRemoveSavedKey,
        onModelSelected: (_) {},
      ),
      locale: locale,
    );

    testWidgets('new: three groups, Check connection, Advanced closed', (
      tester,
    ) async {
      await pumpForm(
        tester,
        const EndpointFormData(profile: 'work', offersUseForNew: true),
      );
      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Shown in the model picker'), findsOneWidget);
      expect(find.text('Address'), findsOneWidget);
      expect(
        find.text(
          'Hermes connects to this address from your server, so localhost means the server itself.',
        ),
        findsOneWidget,
      );
      expect(find.text('API key'), findsOneWidget);
      expect(
        find.text('Leave empty if the server needs none.'),
        findsOneWidget,
      );
      expect(find.text('Check connection'), findsOneWidget);
      expect(find.text('Advanced'), findsOneWidget);
      // Closed: nothing of Advanced is built.
      expect(find.text('Chat Completions'), findsNothing);
      expect(find.text('Use for new chats'), findsOneWidget);
    });

    testWidgets('models found: banner, Model, Hermes will use, switch footer', (
      tester,
    ) async {
      await pumpForm(
        tester,
        const EndpointFormData(
          profile: 'work',
          check: EndpointCheck.found,
          models: ['example-model-a', 'example-model-b'],
          selectedModel: 'example-model-a',
          resolvedAddress: 'https://gpu-box.example.net/v1',
          offersUseForNew: true,
          currentModelName: 'Example Model A',
        ),
      );
      expect(find.text('Found 2 models'), findsOneWidget);
      expect(find.text('Model'), findsOneWidget);
      expect(find.text('example-model-a'), findsOneWidget);
      expect(
        find.text('Hermes will use https://gpu-box.example.net/v1'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Keeps Example Model A for new chats when off. You can change it later.',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'first endpoint: no switch, the footer says it becomes default',
      (tester) async {
        await pumpForm(tester, const EndpointFormData(profile: 'work'));
        expect(find.text('Use for new chats'), findsNothing);
        expect(
          find.text(
            'New chats in work will use this endpoint, since there is no default model yet.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('no models listed opens Advanced and focuses Model', (
      tester,
    ) async {
      await pumpForm(tester, const EndpointFormData(profile: 'work'));
      await pumpForm(
        tester,
        const EndpointFormData(
          profile: 'work',
          check: EndpointCheck.noModels,
          warning: 'The server answered, but listed no models.',
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(
        find.text('The server answered, but listed no models.'),
        findsOneWidget,
      );
      expect(find.text('Chat Completions'), findsOneWidget);
      final focused = FocusManager.instance.primaryFocus;
      expect(focused, isNotNull);
      expect(find.byType(EditableText).evaluate().length, greaterThan(0));
      final modelField = tester
          .widgetList<EditableText>(find.byType(EditableText))
          .last;
      expect(modelField.focusNode.hasFocus, isTrue);
    });

    testWidgets('unreachable and a check without an answer', (tester) async {
      await pumpForm(
        tester,
        const EndpointFormData(
          profile: 'work',
          check: EndpointCheck.unreachable,
          checkedAddress: 'https://gpu-box.example.net',
        ),
      );
      expect(find.text("Couldn't connect"), findsOneWidget);
      expect(
        find.text(
          "Hermes couldn't reach https://gpu-box.example.net from your server.",
        ),
        findsOneWidget,
      );
      await pumpForm(
        tester,
        const EndpointFormData(profile: 'work', check: EndpointCheck.failed),
      );
      expect(find.text("Couldn't check the connection"), findsOneWidget);
    });

    testWidgets('an unencrypted address with a key warns', (tester) async {
      key.text = _fakeKey;
      await pumpForm(
        tester,
        const EndpointFormData(profile: 'work', insecureKey: true),
      );
      expect(find.text("This address isn't encrypted"), findsOneWidget);
      expect(
        find.text('Your key would be sent to it in plain text.'),
        findsOneWidget,
      );
    });

    testWidgets('the check says the key was not sent', (tester) async {
      await pumpForm(
        tester,
        const EndpointFormData(profile: 'work', keyNotSent: true),
      );
      expect(find.text('Checked without your key'), findsOneWidget);
      expect(
        find.text("The key wasn't sent because the address isn't encrypted."),
        findsOneWidget,
      );
    });

    testWidgets('edit with a saved key', (tester) async {
      var removed = 0;
      await pumpForm(
        tester,
        const EndpointFormData(
          profile: 'work',
          editing: true,
          endpointName: 'My GPU box',
          hasSavedKey: true,
        ),
        onRemoveSavedKey: () => removed++,
      );
      expect(find.text('Saved key'), findsOneWidget);
      expect(find.text('Remove saved key'), findsOneWidget);
      expect(
        find.text('Type a new key to replace the saved one.'),
        findsOneWidget,
      );
      expect(find.text('Use for new chats'), findsNothing);
      await tester.tap(find.text('Remove saved key'));
      expect(removed, 1);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(EndpointForm)),
      );
      expect(
        endpointFormTitle(
          l10n,
          const EndpointFormData(
            profile: 'work',
            editing: true,
            endpointName: 'My GPU box',
          ),
        ),
        'Edit My GPU box',
      );
    });

    testWidgets('saving, and the inline errors', (tester) async {
      await pumpForm(
        tester,
        const EndpointFormData(profile: 'work', saving: true),
      );
      expect(find.text('Saving…'), findsOneWidget);
      await pumpForm(
        tester,
        const EndpointFormData(
          profile: 'work',
          issue: EndpointFormIssue.scheme,
        ),
      );
      expect(
        find.text('Address must start with http:// or https://'),
        findsOneWidget,
      );
    });

    testWidgets('Save needs a name, an address and a model', (tester) async {
      const base = EndpointFormData(profile: 'work');
      expect(base.canSave(name: 'a', address: 'b', typedModel: ''), isFalse);
      expect(base.canSave(name: 'a', address: 'b', typedModel: 'm'), isTrue);
      expect(base.canSave(name: '', address: 'b', typedModel: 'm'), isFalse);
      const found = EndpointFormData(profile: 'work', selectedModel: 'm');
      expect(found.canSave(name: 'a', address: 'b', typedModel: ''), isTrue);
    });

    testWidgets(
      'the key is hidden while saving and cleared after a lost answer',
      (tester) async {
        key.text = _fakeKey;
        await pumpForm(tester, const EndpointFormData(profile: 'work'));
        expect(
          tester
              .widget<EditableText>(find.byType(EditableText).at(2))
              .obscureText,
          isTrue,
        );
        await pumpForm(
          tester,
          const EndpointFormData(profile: 'work', saving: true),
        );
        await pumpForm(
          tester,
          const EndpointFormData(profile: 'work', unknown: true),
        );
        await tester.pump();
        expect(key.text, isEmpty);
        expect(
          find.text("Couldn't tell whether the endpoint was saved"),
          findsOneWidget,
        );
      },
    );

    testWidgets('a refusal keeps the typed key', (tester) async {
      key.text = _fakeKey;
      await pumpForm(
        tester,
        const EndpointFormData(profile: 'work', saving: true),
      );
      await pumpForm(
        tester,
        const EndpointFormData(
          profile: 'work',
          refused: true,
          message: 'Name taken.',
        ),
      );
      await tester.pump();
      expect(key.text, _fakeKey);
      expect(find.text('Name taken.'), findsOneWidget);
    });

    testWidgets('German and the largest text size', (tester) async {
      await pumpForm(
        tester,
        const EndpointFormData(profile: 'work'),
        locale: const Locale('de'),
      );
      expect(find.text('Verbindung prüfen'), findsOneWidget);
      await _pump(
        tester,
        EndpointForm(
          data: const EndpointFormData(
            profile: 'work',
            check: EndpointCheck.found,
            models: ['example-model-a'],
            selectedModel: 'example-model-a',
          ),
          nameController: name,
          addressController: address,
          keyController: key,
          modelController: model,
        ),
        scale: 3,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('DefaultModelStep', () {
    DefaultStepData step(
      DefaultStepView view, {
      DefaultStepNote note = DefaultStepNote.none,
      String? model = 'Example Model B',
      String? current = 'Example Model A',
      bool failed = false,
    }) => DefaultStepData(
      view: view,
      providerName: 'OpenRouter',
      profile: 'work',
      modelName: model,
      currentModelName: current,
      note: note,
      failed: failed,
    );

    testWidgets("you're ready", (tester) async {
      await _pump(tester, DefaultModelStep(data: step(DefaultStepView.ready)));
      expect(find.text("You're ready"), findsOneWidget);
      expect(
        find.text('New chats in work use Example Model B from OpenRouter.'),
        findsOneWidget,
      );
      expect(find.text('Start chatting'), findsOneWidget);
      expect(find.text('Change model'), findsOneWidget);
    });

    testWidgets('notes for a key that was not checked', (tester) async {
      await _pump(
        tester,
        DefaultModelStep(
          data: step(DefaultStepView.ready, note: DefaultStepNote.unchecked),
        ),
      );
      expect(find.text('Saved'), findsOneWidget);
      expect(
        find.text('Your first chat will show whether the key works.'),
        findsOneWidget,
      );
      await _pump(
        tester,
        DefaultModelStep(
          data: step(DefaultStepView.ready, note: DefaultStepNote.unreachable),
        ),
      );
      expect(
        find.text("Saved, but Hermes couldn't reach OpenRouter to check it."),
        findsOneWidget,
      );
    });

    testWidgets('later provider: Use, Keep, Choose another', (tester) async {
      final log = <String>[];
      await _pump(
        tester,
        DefaultModelStep(
          data: step(DefaultStepView.later),
          onUseModel: () => log.add('use'),
          onKeepModel: () => log.add('keep'),
          onChangeModel: () => log.add('choose'),
        ),
      );
      expect(find.text('Use Example Model B for new chats?'), findsOneWidget);
      expect(
        find.text(
          "OpenRouter recommends it. You're using Example Model A now.",
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Use Example Model B'));
      await tester.tap(find.text('Keep Example Model A'));
      await tester.tap(find.text('Choose another model…'));
      expect(log, ['use', 'keep', 'choose']);
    });

    testWidgets('no recommendation: Choose model and Not now', (tester) async {
      await _pump(
        tester,
        DefaultModelStep(data: step(DefaultStepView.choose, model: null)),
      );
      expect(find.text('Choose a model for new chats'), findsOneWidget);
      expect(find.text('Choose model'), findsOneWidget);
      expect(find.text('Not now'), findsOneWidget);
      expect(find.text("You're ready"), findsNothing);
    });

    testWidgets('models still loading: warning and Retry', (tester) async {
      var retries = 0;
      await _pump(
        tester,
        DefaultModelStep(
          data: step(DefaultStepView.loading),
          onRetry: () => retries++,
        ),
      );
      expect(
        find.text("Hermes is still loading this provider's models."),
        findsOneWidget,
      );
      await tester.tap(find.text('Retry'));
      expect(retries, 1);
    });

    testWidgets('German', (tester) async {
      await _pump(
        tester,
        DefaultModelStep(data: step(DefaultStepView.ready)),
        locale: const Locale('de'),
      );
      expect(find.text('Du bist startklar'), findsOneWidget);
    });
  });

  group('ConnectModelCard', () {
    testWidgets('the three variants', (tester) async {
      var taps = 0;
      await _pump(
        tester,
        ConnectModelCard(
          data: const ConnectCardData(
            kind: ConnectCardKind.connect,
            profile: 'work',
          ),
          onPressed: () => taps++,
        ),
      );
      expect(find.text('Connect a model to start chatting'), findsOneWidget);
      expect(
        find.text('Your Hermes server has no model provider for work yet.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Connect a model'));
      expect(taps, 1);

      await _pump(
        tester,
        const ConnectModelCard(
          data: ConnectCardData(
            kind: ConnectCardKind.reconnect,
            profile: 'work',
            modelName: 'Example Model A',
          ),
        ),
      );
      expect(find.text("Reconnect your model's provider"), findsOneWidget);
      expect(find.text('Reconnect'), findsOneWidget);
      expect(
        find.text(
          "New chats in work use Example Model A, but its provider's key is missing or no longer works.",
        ),
        findsOneWidget,
      );

      await _pump(
        tester,
        const ConnectModelCard(
          data: ConnectCardData(kind: ConnectCardKind.loading, profile: 'work'),
        ),
      );
      expect(find.text('Hermes is loading your models'), findsOneWidget);
      expect(find.text('Check again'), findsOneWidget);
    });

    testWidgets('is at most 420 wide', (tester) async {
      tester.view
        ..physicalSize = const Size(1000, 800)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildHermesLightTheme(),
          home: const Scaffold(
            body: Center(
              child: ConnectModelCard(
                data: ConnectCardData(
                  kind: ConnectCardKind.connect,
                  profile: 'work',
                ),
              ),
            ),
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(ConnectModelCard)).width,
        lessThanOrEqualTo(420),
      );
    });

    testWidgets('a failed reply offers Check model providers', (tester) async {
      var taps = 0;
      await _pump(
        tester,
        ProviderReplyFailure(
          message: 'No credit left.',
          onCheckProviders: () => taps++,
        ),
      );
      expect(find.text('The reply failed'), findsOneWidget);
      expect(find.text('No credit left.'), findsOneWidget);
      await tester.tap(find.text('Check model providers'));
      expect(taps, 1);
    });
  });

  group('alerts', () {
    Future<bool?> open(
      WidgetTester tester,
      Future<bool> Function(BuildContext) ask, {
      TargetPlatform platform = TargetPlatform.iOS,
    }) async {
      bool? result;
      await _pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await ask(context),
            child: const Text('open'),
          ),
        ),
        platform: platform,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('Remove key names the provider and the profile', (
      tester,
    ) async {
      await open(
        tester,
        (c) => confirmRemoveKey(c, provider: 'OpenRouter', profile: 'work'),
      );
      expect(find.text('Remove the OpenRouter key?'), findsOneWidget);
      expect(
        find.text('work can no longer use OpenRouter models.'),
        findsOneWidget,
      );
      expect(find.text('Remove key'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('serving the default adds the new chats sentence', (
      tester,
    ) async {
      await open(
        tester,
        (c) => confirmRemoveKey(
          c,
          provider: 'OpenRouter',
          profile: 'work',
          servesDefault: true,
        ),
      );
      expect(
        find.text(
          "work can no longer use OpenRouter models. New chats in work can't start until you pick another model.",
        ),
        findsOneWidget,
      );
    });

    testWidgets('Cancel answers false and changes nothing', (tester) async {
      var result = true;
      await _pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await confirmSignOut(
              context,
              provider: 'Nous Portal',
              profile: 'work',
            ),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Sign out of Nous Portal?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });

    testWidgets('the action answers true', (tester) async {
      var result = false;
      await _pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await confirmDeleteEndpoint(
              context,
              name: 'My GPU box',
              profile: 'work',
            ),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Delete My GPU box?'), findsOneWidget);
      expect(find.text('Its saved key is deleted too.'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });

    testWidgets('on Android both are text buttons, Cancel first, action red', (
      tester,
    ) async {
      await open(
        tester,
        (c) => confirmStopSignIn(c, provider: 'ChatGPT'),
        platform: TargetPlatform.android,
      );
      expect(find.text('Stop signing in to ChatGPT?'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      final keep = tester.getTopLeft(find.text('Keep waiting'));
      final stop = tester.getTopLeft(find.text('Stop'));
      expect(keep.dx, lessThan(stop.dx));
      final style = tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Stop'))
          .style!;
      final red = Theme.of(tester.element(find.text('Stop'))).colorScheme.error;
      expect(style.foregroundColor!.resolve({}), red);
    });

    testWidgets('on iOS Cancel is the bold default, the action destructive', (
      tester,
    ) async {
      await open(
        tester,
        (c) => confirmCleartextKey(c, address: 'models.example.net'),
      );
      expect(find.text('Send the key unencrypted?'), findsOneWidget);
      expect(find.text('Save anyway'), findsOneWidget);
      final cancel = tester.widget<CupertinoDialogAction>(
        find.ancestor(
          of: find.text('Cancel'),
          matching: find.byType(CupertinoDialogAction),
        ),
      );
      expect(cancel.isDefaultAction, isTrue);
    });

    testWidgets('the expensive model alert carries Hermes message', (
      tester,
    ) async {
      await open(
        tester,
        (c) => confirmExpensiveModel(c, message: 'It costs a lot.'),
      );
      expect(find.text('Use this model?'), findsOneWidget);
      expect(find.text('It costs a lot.'), findsOneWidget);
      expect(find.text('Use it anyway'), findsOneWidget);
    });

    testWidgets('Remove saved key and German', (tester) async {
      await open(
        tester,
        (c) => confirmRemoveEndpointKey(c, name: 'My GPU box'),
      );
      expect(find.text('Remove the saved key for My GPU box?'), findsOneWidget);
      expect(find.text('Hermes will connect without a key.'), findsOneWidget);
    });
  });
}
