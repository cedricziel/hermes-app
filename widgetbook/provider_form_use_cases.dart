import 'package:flutter/material.dart';
import 'package:hermes_app/src/providers/widgets/api_key_form.dart';
import 'package:hermes_app/src/providers/widgets/connect_model_card.dart';
import 'package:hermes_app/src/providers/widgets/default_model_step.dart';
import 'package:hermes_app/src/providers/widgets/endpoint_form.dart';
import 'package:hermes_app/src/providers/widgets/provider_alerts.dart';
import 'package:hermes_app/src/providers/widgets/provider_form_models.dart';
import 'package:hermes_app/src/providers/widgets/provider_view_models.dart';
import 'package:hermes_app/src/providers/widgets/server_command_view.dart';
import 'package:hermes_app/src/providers/widgets/sign_in_code_view.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';
import 'host.dart';
import 'provider_use_case_helpers.dart';

// ---- invented sample data: example addresses, a fake key, neutral models ----

/// Obviously not a key.
const _fakeKey = 'test-key-not-real';

WidgetbookUseCase _case(String name, Widget Function(BuildContext) builder) =>
    WidgetbookUseCase(name: name, builder: builder);

// ---- the API key form ----

const _keyFormBase = ApiKeyFormData(
  providerName: 'OpenRouter',
  profile: 'work',
  offersKeyLink: true,
);

/// The form on a settings page, with the bar's Save following the field, the
/// way the screen will wire it. A dialog (the Mac's, or a wide window's) is
/// the same page inside a [Dialog].
class _KeyFormDemo extends StatefulWidget {
  const _KeyFormDemo({
    required this.data,
    this.text = '',
    this.shown = false,
    this.dialog = false,
  });

  final ApiKeyFormData data;
  final String text;
  final bool shown;
  final bool dialog;

  @override
  State<_KeyFormDemo> createState() => _KeyFormDemoState();
}

class _KeyFormDemoState extends State<_KeyFormDemo> {
  late final _controller = TextEditingController(text: widget.text);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final page = ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => settingsPage(
        title: (l10n) => apiKeyFormTitle(l10n, widget.data),
        subtitle: (_) => widget.data.profile,
        cancel: true,
        formAction: (l10n) => apiKeyFormAction(
          l10n,
          widget.data,
          hasText: _controller.text.isNotEmpty,
          onSave: noop,
        ),
        body: ApiKeyForm(
          data: widget.data,
          controller: _controller,
          initiallyShown: widget.shown,
          onSave: noopId,
          onSaveAnyway: noopId,
          onTryAgain: noopId,
          onOpenKeyLink: noop,
          onUseAccount: noop,
        ),
      ),
    );
    if (!widget.dialog) return page;
    return Center(
      child: Dialog(
        clipBehavior: Clip.antiAlias,
        child: SizedBox(width: 480, height: 640, child: page),
      ),
    );
  }
}

Widget _keyForm(
  ApiKeyFormData data, {
  String text = '',
  bool shown = false,
  bool dialog = false,
  double scale = 1,
}) => scaled(
  scale,
  _KeyFormDemo(data: data, text: text, shown: shown, dialog: dialog),
);

ApiKeyFormData _keyIn(
  ApiKeyPhase phase, {
  String? message,
  bool notAccepted = false,
  bool emptyKey = false,
  bool replacing = false,
  bool keyLink = true,
}) => ApiKeyFormData(
  providerName: 'OpenRouter',
  profile: 'work',
  phase: phase,
  message: message,
  notAccepted: notAccepted,
  emptyKey: emptyKey,
  replacing: replacing,
  offersKeyLink: keyLink,
);

const _rejectedMessage =
    'That API key was rejected. Double-check it and try again.';
const _providerDownMessage = 'Provider returned HTTP 503 for this key.';
const _lockedMessage = 'This key is managed by an administrator.';

WidgetbookComponent _apiKeyComponent() => WidgetbookComponent(
  name: 'ApiKeyForm',
  useCases: [
    ...onEachPlatform('Empty, Save disabled', (_) => _keyForm(_keyFormBase)),
    _case(
      'With the account link',
      (_) => _keyForm(
        const ApiKeyFormData(
          providerName: 'Anthropic',
          profile: 'work',
          offersKeyLink: true,
          offersAccount: true,
        ),
      ),
    ),
    _case(
      'Key typed, hidden',
      (_) => _keyForm(_keyFormBase, text: 'test-key-not-real-0123456789'),
    ),
    _case(
      'Key shown (a fake key)',
      (_) => _keyForm(_keyFormBase, text: _fakeKey, shown: true),
    ),
    _case(
      'Empty save: Paste the key first',
      (_) => _keyForm(_keyIn(ApiKeyPhase.editing, emptyKey: true), text: '   '),
    ),
    _case(
      'Checking: Save is a spinner, key hidden',
      (_) => _keyForm(_keyIn(ApiKeyPhase.checking), text: _fakeKey),
    ),
    _case(
      'Saving',
      (_) => _keyForm(_keyIn(ApiKeyPhase.saving), text: _fakeKey),
    ),
    ...onEachPlatform(
      'Rejected: Edit key and Save anyway',
      (_) => _keyForm(
        _keyIn(ApiKeyPhase.rejected, message: _rejectedMessage),
        text: _fakeKey,
      ),
    ),
    ...onEachPlatform(
      'Provider error: Save anyway and Try again',
      (_) => _keyForm(
        _keyIn(ApiKeyPhase.providerError, message: _providerDownMessage),
        text: _fakeKey,
      ),
    ),
    _case(
      'Refused: locked, key kept hidden',
      (_) => _keyForm(
        _keyIn(ApiKeyPhase.refused, message: _lockedMessage),
        text: _fakeKey,
      ),
    ),
    _case(
      "422: Hermes didn't accept the request",
      (_) => _keyForm(
        _keyIn(ApiKeyPhase.refused, notAccepted: true),
        text: _fakeKey,
      ),
    ),
    _case(
      'Outcome unknown, first key: field cleared',
      (_) => _keyForm(_keyIn(ApiKeyPhase.unknown)),
    ),
    _case(
      'Outcome unknown, replacement: field cleared',
      (_) => _keyForm(_keyIn(ApiKeyPhase.unknown, replacing: true)),
    ),
    _case(
      'Replace key',
      (_) => _keyForm(_keyIn(ApiKeyPhase.editing, replacing: true)),
    ),
    _case(
      'No key link (address not https)',
      (_) => _keyForm(_keyIn(ApiKeyPhase.editing, keyLink: false)),
    ),
    _case(
      'Mac dialog',
      (context) => Theme(
        data: Theme.of(context).copyWith(platform: TargetPlatform.macOS),
        child: _keyForm(
          _keyIn(ApiKeyPhase.rejected, message: _rejectedMessage),
          text: _fakeKey,
          dialog: true,
        ),
      ),
    ),
    _case(
      'Android full-screen dialog',
      (context) => Theme(
        data: Theme.of(context).copyWith(platform: TargetPlatform.android),
        child: _keyForm(
          _keyIn(ApiKeyPhase.providerError, message: _providerDownMessage),
          text: _fakeKey,
        ),
      ),
    ),
    _case(
      'Largest text, rejected',
      (_) => _keyForm(
        _keyIn(ApiKeyPhase.rejected, message: _rejectedMessage),
        text: _fakeKey,
        scale: 3,
      ),
    ),
    _case(
      'Largest text, provider error',
      (_) => _keyForm(
        _keyIn(ApiKeyPhase.providerError, message: _providerDownMessage),
        text: _fakeKey,
        scale: 3,
      ),
    ),
  ],
);

// ---- the sign-in step ----

SignInCodeData _signIn({
  SignInStepPhase phase = SignInStepPhase.waiting,
  String provider = 'ChatGPT',
  String? code = 'WDJB-MJHT',
  bool codeInLink = false,
  bool canOpen = true,
  bool offline = false,
  int? expires = 14,
  String? message,
}) => SignInCodeData(
  providerName: provider,
  profile: 'work',
  phase: phase,
  code: code,
  codeInLink: codeInLink,
  canOpen: canOpen,
  offline: offline,
  expiresInMinutes: expires,
  message: message,
);

Widget _signInPage(
  SignInCodeData data, {
  double scale = 1,
  bool initiallyCopied = false,
}) => scaled(
  scale,
  settingsPage(
    title: (l10n) => l10n.providersSignInTitle(data.providerName),
    subtitle: (_) => data.profile,
    cancel: true,
    body: SignInCodeView(
      data: data,
      initiallyCopied: initiallyCopied,
      onOpen: noop,
      onCopied: noop,
      onStartAgain: noop,
      onCheckAgain: noop,
    ),
  ),
);

WidgetbookComponent _signInComponent() => WidgetbookComponent(
  name: 'SignInCodeView',
  useCases: [
    ...onEachPlatform('Waiting', (_) => _signInPage(_signIn())),
    _case(
      'Nous: Check that this code matches',
      (_) => _signInPage(
        _signIn(provider: 'Nous Portal', code: 'KFPR-2QWX', codeInLink: true),
      ),
    ),
    _case("Can't reach the server", (_) => _signInPage(_signIn(offline: true))),
    _case(
      'Copied, for two seconds',
      (_) => _signInPage(_signIn(), initiallyCopied: true),
    ),
    _case(
      'No Open button (address not safe)',
      (_) => _signInPage(_signIn(canOpen: false)),
    ),
    _case(
      'Declined',
      (_) => _signInPage(
        _signIn(phase: SignInStepPhase.declined, code: null, expires: null),
      ),
    ),
    _case(
      'Expired',
      (_) => _signInPage(
        _signIn(phase: SignInStepPhase.expired, code: null, expires: null),
      ),
    ),
    _case(
      "Failed, with Hermes' message",
      (_) => _signInPage(
        _signIn(
          phase: SignInStepPhase.failed,
          code: null,
          expires: null,
          message: 'The provider is not accepting sign-ins right now.',
        ),
      ),
    ),
    _case(
      'Failed, without a message',
      (_) => _signInPage(
        _signIn(phase: SignInStepPhase.failed, code: null, expires: null),
      ),
    ),
    _case(
      'Start refused: Check again, no code',
      (_) => _signInPage(
        _signIn(
          phase: SignInStepPhase.startRefused,
          provider: 'Nous Portal',
          code: null,
          expires: null,
          message: 'Nous Portal is already signed in.',
        ),
      ),
    ),
    _case(
      'Start got no answer',
      (_) => _signInPage(
        _signIn(phase: SignInStepPhase.startFailed, code: null, expires: null),
      ),
    ),
    _case(
      'Largest text: the code wraps by group, buttons stacked',
      (_) => _signInPage(_signIn(), scale: 3),
    ),
    _case(
      'Largest text, declined',
      (_) => _signInPage(
        _signIn(phase: SignInStepPhase.declined, code: null),
        scale: 3,
      ),
    ),
  ],
);

// ---- Connect on your server ----

Widget _serverPage({bool checking = false, double scale = 1}) => scaled(
  scale,
  settingsPage(
    title: (_) => 'Anthropic',
    subtitle: (_) => 'work',
    formAction: (l10n) => serverCommandFormAction(l10n, onDone: noop),
    body: ServerCommandView(
      data: ServerCommandData(
        providerName: 'Anthropic',
        profile: 'work',
        command: 'hermes auth add anthropic',
        checking: checking,
      ),
      onCheckAgain: noop,
    ),
  ),
);

WidgetbookComponent _serverComponent() => WidgetbookComponent(
  name: 'ServerCommandView',
  useCases: [
    ...onEachPlatform('Command and Check again', (_) => _serverPage()),
    _case('Checking again', (_) => _serverPage(checking: true)),
    _case('Largest text', (_) => _serverPage(scale: 3)),
  ],
);

// ---- the custom endpoint form ----

const _endpointModels = ['example-model-a', 'example-model-b'];
const _endpointAddress = 'https://gpu-box.example.net:8000';

EndpointFormData _endpoint({
  bool editing = false,
  bool hasSavedKey = false,
  EndpointCheck check = EndpointCheck.none,
  List<String> models = const [],
  String? selectedModel,
  String? resolved,
  String? warning,
  bool keyNotSent = false,
  bool insecureKey = false,
  bool offersUseForNew = true,
  bool useForNew = false,
  bool saving = false,
  EndpointFormIssue issue = EndpointFormIssue.none,
  bool refused = false,
  String? message,
  bool notAccepted = false,
  bool unknown = false,
}) => EndpointFormData(
  profile: 'work',
  editing: editing,
  endpointName: 'My GPU box',
  hasSavedKey: hasSavedKey,
  check: check,
  models: models,
  selectedModel: selectedModel,
  resolvedAddress: resolved,
  checkedAddress: _endpointAddress,
  warning: warning,
  keyNotSent: keyNotSent,
  insecureKey: insecureKey,
  offersUseForNew: offersUseForNew,
  useForNew: useForNew,
  currentModelName: 'Example Model A',
  saving: saving,
  issue: issue,
  refused: refused,
  message: message,
  notAccepted: notAccepted,
  unknown: unknown,
  apiType: ProviderApiType.automatic,
);

final _endpointFound = _endpoint(
  check: EndpointCheck.found,
  models: _endpointModels,
  selectedModel: 'example-model-a',
  resolved: '$_endpointAddress/v1',
  useForNew: true,
);

/// The form on a settings page, with its own text controllers. With [then]
/// the form first shows [data] and moves on to [then] after a frame, so a
/// transition (a check that finds no models) runs the way it does in the app.
class _EndpointDemo extends StatefulWidget {
  const _EndpointDemo({
    required this.data,
    this.then,
    this.name = '',
    this.address = '',
    this.typedKey = '',
    this.model = '',
    this.shown = false,
    this.advancedOpen = false,
    this.dialog = false,
  });

  final EndpointFormData data;
  final EndpointFormData? then;
  final String name;
  final String address;
  final String typedKey;
  final String model;
  final bool shown;
  final bool advancedOpen;
  final bool dialog;

  @override
  State<_EndpointDemo> createState() => _EndpointDemoState();
}

class _EndpointDemoState extends State<_EndpointDemo> {
  late final _name = TextEditingController(text: widget.name);
  late final _address = TextEditingController(text: widget.address);
  late final _key = TextEditingController(text: widget.typedKey);
  late final _model = TextEditingController(text: widget.model);
  late var _data = widget.data;

  @override
  void initState() {
    super.initState();
    final then = widget.then;
    if (then != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _data = then);
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _key.dispose();
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final page = ListenableBuilder(
      listenable: Listenable.merge([_name, _address, _model]),
      builder: (context, _) => settingsPage(
        title: (l10n) => endpointFormTitle(l10n, _data),
        subtitle: (_) => _data.profile,
        cancel: true,
        formAction: (l10n) => endpointFormAction(
          l10n,
          _data,
          canSave: _data.canSave(
            name: _name.text,
            address: _address.text,
            typedModel: _model.text,
          ),
          onSave: noop,
        ),
        body: EndpointForm(
          data: _data,
          nameController: _name,
          addressController: _address,
          keyController: _key,
          modelController: _model,
          initiallyShown: widget.shown,
          initiallyAdvancedOpen: widget.advancedOpen,
          onCheck: noop,
          onModelSelected: noopId,
          onApiTypeChanged: (_) {},
          onUseForNewChanged: (_) {},
          onRemoveSavedKey: noop,
        ),
      ),
    );
    if (!widget.dialog) return page;
    return Center(
      child: Dialog(
        clipBehavior: Clip.antiAlias,
        child: SizedBox(width: 480, height: 700, child: page),
      ),
    );
  }
}

Widget _endpointForm(
  EndpointFormData data, {
  EndpointFormData? then,
  String name = 'My GPU box',
  String address = _endpointAddress,
  String key = '',
  String model = '',
  bool shown = false,
  bool advancedOpen = false,
  bool dialog = false,
  double scale = 1,
}) => scaled(
  scale,
  _EndpointDemo(
    data: data,
    then: then,
    name: name,
    address: address,
    typedKey: key,
    model: model,
    shown: shown,
    advancedOpen: advancedOpen,
    dialog: dialog,
  ),
);

WidgetbookComponent _endpointComponent() => WidgetbookComponent(
  name: 'EndpointForm',
  useCases: [
    ...onEachPlatform(
      'New, Advanced closed',
      (_) => _endpointForm(
        _endpoint(offersUseForNew: false),
        name: '',
        address: '',
      ),
    ),
    ...onEachPlatform(
      'Models found, Use for new chats',
      (_) => _endpointForm(_endpointFound),
    ),
    _case(
      'First endpoint: it becomes the default',
      (_) => _endpointForm(
        _endpoint(
          check: EndpointCheck.found,
          models: _endpointModels,
          selectedModel: 'example-model-a',
          offersUseForNew: false,
        ),
      ),
    ),
    _case(
      'No models listed: Advanced opens, Model focused',
      (_) => _endpointForm(
        _endpoint(),
        then: _endpoint(
          check: EndpointCheck.noModels,
          warning: 'The server answered, but listed no models.',
        ),
      ),
    ),
    _case(
      'No models listed, Hermes gave no message',
      (_) => _endpointForm(
        _endpoint(check: EndpointCheck.noModels),
        advancedOpen: true,
      ),
    ),
    _case(
      "Unreachable: Couldn't connect",
      (_) => _endpointForm(_endpoint(check: EndpointCheck.unreachable)),
    ),
    _case(
      'Check got no answer',
      (_) => _endpointForm(_endpoint(check: EndpointCheck.failed)),
    ),
    _case(
      'Checking',
      (_) => _endpointForm(_endpoint(check: EndpointCheck.checking)),
    ),
    _case(
      "Unencrypted address with a key: This address isn't encrypted",
      (_) => _endpointForm(
        _endpoint(insecureKey: true),
        address: 'http://models.example.net/v1',
        key: _fakeKey,
      ),
    ),
    _case(
      'Check connection left the key out',
      (_) => _endpointForm(
        _endpoint(
          check: EndpointCheck.found,
          models: _endpointModels,
          selectedModel: 'example-model-a',
          insecureKey: true,
          keyNotSent: true,
        ),
        address: 'http://models.example.net/v1',
        key: _fakeKey,
      ),
    ),
    _case(
      'Edit with a saved key',
      (_) => _endpointForm(
        _endpoint(
          editing: true,
          hasSavedKey: true,
          check: EndpointCheck.found,
          models: _endpointModels,
          selectedModel: 'example-model-a',
        ),
      ),
    ),
    _case(
      'Key shown (a fake key)',
      (_) => _endpointForm(_endpoint(), key: _fakeKey, shown: true),
    ),
    _case(
      'Saving',
      (_) => _endpointForm(
        _endpoint(
          saving: true,
          check: EndpointCheck.found,
          models: _endpointModels,
          selectedModel: 'example-model-a',
        ),
        key: _fakeKey,
      ),
    ),
    _case(
      'Inline error: address needs a scheme',
      (_) => _endpointForm(
        _endpoint(issue: EndpointFormIssue.scheme),
        address: 'gpu-box.example.net',
      ),
    ),
    _case(
      'Inline error: no model',
      (_) => _endpointForm(
        _endpoint(
          check: EndpointCheck.noModels,
          issue: EndpointFormIssue.model,
          warning: 'The server answered, but listed no models.',
        ),
        advancedOpen: true,
      ),
    ),
    _case(
      "Refused, with Hermes' reason",
      (_) => _endpointForm(
        _endpoint(
          refused: true,
          message: 'An endpoint with this name exists already.',
        ),
      ),
    ),
    _case(
      "422: Hermes didn't accept the request",
      (_) => _endpointForm(_endpoint(notAccepted: true), key: _fakeKey),
    ),
    _case(
      'Outcome unknown: key cleared',
      (_) => _endpointForm(_endpoint(unknown: true)),
    ),
    _case(
      'Mac dialog',
      (context) => Theme(
        data: Theme.of(context).copyWith(platform: TargetPlatform.macOS),
        child: _endpointForm(_endpointFound, dialog: true),
      ),
    ),
    _case(
      'Largest text, models found',
      (_) => _endpointForm(_endpointFound, scale: 3),
    ),
  ],
);

// ---- the default-model step ----

DefaultStepData _step(
  DefaultStepView view, {
  DefaultStepNote note = DefaultStepNote.none,
  bool failed = false,
  bool busy = false,
  String? model = 'Example Model A',
  String? current,
  String provider = 'OpenRouter',
}) => DefaultStepData(
  view: view,
  providerName: provider,
  profile: 'work',
  modelName: model,
  currentModelName: current,
  note: note,
  failed: failed,
  busy: busy,
);

Widget _stepPage(DefaultStepData data, {double scale = 1}) => scaled(
  scale,
  settingsPage(
    title: (_) => data.providerName,
    subtitle: (_) => data.profile,
    cancel: true,
    body: DefaultModelStep(
      data: data,
      onStartChatting: noop,
      onChangeModel: noop,
      onUseModel: noop,
      onKeepModel: noop,
      onChooseModel: noop,
      onNotNow: noop,
      onRetry: noop,
    ),
  ),
);

WidgetbookComponent _stepComponent() => WidgetbookComponent(
  name: 'DefaultModelStep',
  useCases: [
    ...onEachPlatform(
      "You're ready",
      (_) => _stepPage(_step(DefaultStepView.ready)),
    ),
    _case(
      'Key not checked (also after Save anyway)',
      (_) => _stepPage(
        _step(DefaultStepView.ready, note: DefaultStepNote.unchecked),
      ),
    ),
    _case(
      "Hermes couldn't reach the provider",
      (_) => _stepPage(
        _step(DefaultStepView.ready, note: DefaultStepNote.unreachable),
      ),
    ),
    ...onEachPlatform(
      'Later provider: Use, Keep, Choose another',
      (_) => _stepPage(
        _step(
          DefaultStepView.later,
          provider: 'Nous Portal',
          model: 'Example Model B',
          current: 'Example Model A',
        ),
      ),
    ),
    _case(
      'No recommendation: Choose model, Not now',
      (_) => _stepPage(_step(DefaultStepView.choose, model: null)),
    ),
    _case(
      'Nous moved the default',
      (_) => _stepPage(
        _step(
          DefaultStepView.ready,
          provider: 'Nous Portal',
          model: 'Example Model B',
        ),
      ),
    ),
    _case(
      'Models still loading: Retry, nothing saved',
      (_) =>
          _stepPage(_step(DefaultStepView.loading, model: 'Example Model B')),
    ),
    _case(
      'Saving the default failed',
      (_) => _stepPage(_step(DefaultStepView.ready, failed: true)),
    ),
    _case(
      'Saving the default',
      (_) => _stepPage(_step(DefaultStepView.ready, busy: true)),
    ),
    _case(
      'Largest text, later provider',
      (_) => _stepPage(
        _step(
          DefaultStepView.later,
          provider: 'Nous Portal',
          model: 'Example Model B',
          current: 'Example Model A',
        ),
        scale: 3,
      ),
    ),
  ],
);

// ---- the chat's cards ----

Widget _card(ConnectCardData data, {bool centred = false}) => frame(
  centred
      ? Center(
          child: ConnectModelCard(data: data, onPressed: noop),
        )
      : ConnectModelCard(data: data, onPressed: noop),
  maxWidth: centred ? 1000 : 480,
);

const _connectCard = ConnectCardData(
  kind: ConnectCardKind.connect,
  profile: 'work',
);
const _reconnectCard = ConnectCardData(
  kind: ConnectCardKind.reconnect,
  profile: 'work',
  modelName: 'Example Model A',
);
const _loadingCard = ConnectCardData(
  kind: ConnectCardKind.loading,
  profile: 'work',
);

WidgetbookComponent _cardComponent() => WidgetbookComponent(
  name: 'ConnectModelCard',
  useCases: [
    _case('Connect', (_) => _card(_connectCard)),
    _case('Reconnect', (_) => _card(_reconnectCard)),
    _case('Loading', (_) => _card(_loadingCard)),
    _case(
      'Dark',
      (context) => Theme(
        data: buildHermesDarkTheme().copyWith(
          platform: Theme.of(context).platform,
        ),
        child: SizedBox.expand(
          child: Material(
            color: buildHermesDarkTheme().scaffoldBackgroundColor,
            child: _card(_connectCard),
          ),
        ),
      ),
    ),
    _case(
      'Mac: centred, at most 420 pt',
      (context) => Theme(
        data: Theme.of(context).copyWith(platform: TargetPlatform.macOS),
        child: _card(_connectCard, centred: true),
      ),
    ),
    _case('Largest text', (_) => scaled(3, _card(_reconnectCard))),
    _case(
      'Failed reply: Check model providers',
      (_) => frame(
        ProviderReplyFailure(
          message: 'The provider answered 402: the account has no credit left.',
          onCheckProviders: noop,
        ),
        maxWidth: 480,
      ),
    ),
  ],
);

// ---- the alerts ----

/// One use case per platform that matters for an alert: the iOS alert, and
/// the Material alert with two text buttons. The Mac alert is the iOS one.
List<WidgetbookUseCase> _alert(
  String name,
  Future<bool> Function(BuildContext context) ask,
) => [
  for (final (label, platform) in [
    ('iOS', TargetPlatform.iOS),
    ('Android', TargetPlatform.android),
  ])
    WidgetbookUseCase(
      name: '$name ($label)',
      builder: (context) => Theme(
        data: Theme.of(context).copyWith(platform: platform),
        child: Builder(
          builder: (context) => openOnShow((context) async {
            await ask(context);
          }),
        ),
      ),
    ),
];

WidgetbookComponent _alertsComponent() => WidgetbookComponent(
  name: 'Provider alerts',
  useCases: [
    ..._alert(
      'Remove key',
      (c) => confirmRemoveKey(c, provider: 'OpenRouter', profile: 'work'),
    ),
    ..._alert(
      'Remove key, the default model is affected',
      (c) => confirmRemoveKey(
        c,
        provider: 'OpenRouter',
        profile: 'work',
        servesDefault: true,
      ),
    ),
    ..._alert(
      'Sign out',
      (c) => confirmSignOut(c, provider: 'Nous Portal', profile: 'work'),
    ),
    ..._alert(
      'Delete endpoint',
      (c) => confirmDeleteEndpoint(
        c,
        name: 'My GPU box',
        profile: 'work',
        servesDefault: true,
      ),
    ),
    ..._alert(
      'Remove saved key',
      (c) => confirmRemoveEndpointKey(c, name: 'My GPU box'),
    ),
    ..._alert(
      'Stop signing in: Keep waiting is the default',
      (c) => confirmStopSignIn(c, provider: 'ChatGPT'),
    ),
    ..._alert(
      'Send the key unencrypted?',
      (c) => confirmCleartextKey(c, address: 'models.example.net'),
    ),
    ..._alert(
      'Use this model?',
      (c) => confirmExpensiveModel(
        c,
        message: 'Example Model C costs much more per message than the model you use now.',
      ),
    ),
  ],
);

List<WidgetbookNode> providerFormComponents() => [
  _apiKeyComponent(),
  _signInComponent(),
  _serverComponent(),
  _endpointComponent(),
  _stepComponent(),
  _cardComponent(),
  _alertsComponent(),
];
