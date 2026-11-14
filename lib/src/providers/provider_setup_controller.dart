import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_otel/flutter_otel.dart';

import '../auth/server_address.dart';
import 'provider_models.dart';
import 'provider_results.dart';
import 'provider_setup_state.dart';
import 'provider_sign_in.dart';
import 'provider_signals.dart';
import 'providers_repository.dart';

export 'provider_setup_state.dart';

/// Whether saving [address] with a typed key would send the key unencrypted
/// to a host that is not local to the Hermes server: `http://` to a host
/// [isLocalHost] does not accept. "Local" means local to the server, since the
/// server makes the call.
bool endpointSendsKeyUnencrypted(String address, {required bool hasKey}) {
  if (!hasKey) return false;
  final uri = Uri.tryParse(address.trim());
  return uri != null &&
      uri.scheme == 'http' &&
      uri.host.isNotEmpty &&
      !isLocalHost(uri.host);
}

/// The default model as the snapshot read before a flow said it was.
class _DefaultBefore {
  const _DefaultBefore(this.provider, this.model, this.usable);

  final String provider;
  final String model;

  /// A default is set and a connected provider serves it.
  final bool usable;
}

class _StepContext {
  const _StepContext({
    required this.providerId,
    required this.before,
    this.note,
    this.afterSignIn = false,
  });

  final String providerId;
  final _DefaultBefore before;
  final KeyNote? note;
  final bool afterSignIn;
}

class _SignInContext {
  const _SignInContext({required this.before, required this.first});

  final _DefaultBefore before;
  final bool first;
}

class _PendingConfirm {
  _PendingConfirm(this.providerId, this.model, this.span, this.generation);

  final String providerId;
  final String model;
  final Span? span;
  final int generation;
}

/// Connects model providers to one profile: the snapshot of what is
/// connected, the key flow, account sign-ins, custom endpoints, the default
/// model and removals.
///
/// Plain Dart: it exposes enums and typed values, never display text, and it
/// takes a typed key (or endpoint key) as a method argument. A key is never
/// held in a field, a state value, a signal or a message; only the request
/// carries it.
///
/// Every answer is tied to a generation: [bind] to another profile, or a
/// closed form, makes late answers drop. A write that was sent is never sent
/// again; a lost answer is settled by reading the providers again.
class ProviderSetupController extends ChangeNotifier
    with WidgetsBindingObserver {
  ProviderSetupController({
    required this.repository,
    this._profile,
    this._platform,
    bool observeLifecycle = true,
  }) : _signals = ProviderSignals(repository.telemetry) {
    if (observeLifecycle) {
      try {
        WidgetsBinding.instance.addObserver(this);
        _observing = true;
      } on Object {
        // No binding yet (a plain Dart test): lifecycle is forwarded by hand.
      }
    }
  }

  final ProvidersRepository repository;
  final TargetPlatform? _platform;
  final ProviderSignals _signals;
  bool _observing = false;
  bool _disposed = false;

  String? _profile;
  int _generation = 0;
  int _reads = 0;
  int _formSeq = 0;
  int _stepSeq = 0;
  int _endpointSeq = 0;

  /// The profile the screen is open for.
  String? get profile => _profile;

  // ---- what is connected ----

  ProvidersLoaded? _loaded;
  ReadFailure? _failure;
  bool _unsupported = false;
  bool loading = false;

  /// The last providers read that worked; kept when a later read fails, so
  /// the list stays under a warning.
  ProvidersLoaded? get loaded => _loaded;
  ProviderCatalog? get catalog => _loaded?.catalog;

  /// Why the latest read failed; null when it worked.
  ReadFailure? get failure => _failure;

  /// `GET /api/model/options` answered 404: the server has no such screen.
  bool get unsupported => _unsupported;

  /// Counts every successful write (key, sign-in, default model, removal,
  /// endpoint), so pickers elsewhere read their options again.
  int changes = 0;

  /// The default model's id, empty when none.
  String get defaultModel => catalog?.defaultModel ?? '';

  /// Shows the providers of [profile]. Answers still on their way for the
  /// previous profile are dropped; a sign-in started for it keeps following
  /// it.
  void bind(String? profile) {
    if (profile == _profile && (_loaded != null || loading)) return;
    _generation++;
    _profile = profile;
    _loaded = null;
    _failure = null;
    _unsupported = false;
    keyForm = null;
    step = null;
    confirmation = null;
    _endPendingConfirm();
    _stepContext = null;
    endpointForm = const EndpointFormState();
    lastRemoval = null;
    _formSeq++;
    _stepSeq++;
    _endpointSeq++;
    notifyListeners();
    unawaited(load());
  }

  /// Ends the span of a confirmation nobody answered.
  void _endPendingConfirm() {
    final pending = _pendingConfirm;
    _pendingConfirm = null;
    if (pending != null) {
      _signals.end(pending.span, {
        'outcome': 'declined',
        'confirm_asked': true,
      });
    }
  }

  /// Reads the providers again.
  Future<void> load() => _reload();

  Future<bool> _reload() async {
    if (_disposed) return false;
    final generation = _generation;
    final read = ++_reads;
    loading = true;
    _notify();
    final snapshot = await repository.load(_profile);
    if (_disposed || generation != _generation || read != _reads) return false;
    loading = false;
    switch (snapshot) {
      case final ProvidersLoaded loaded:
        _loaded = loaded;
        _failure = null;
        _unsupported = false;
      case ProvidersUnsupported():
        _loaded = null;
        _failure = null;
        _unsupported = true;
      case ProvidersFailed(:final reason):
        _failure = reason;
    }
    _notify();
    return snapshot is ProvidersLoaded;
  }

  /// "Check again": reads the providers and says whether [providerId] is
  /// connected now.
  Future<bool> checkAgain(String providerId) async {
    await _reload();
    return catalog?.byId(providerId)?.connected ?? false;
  }

  _DefaultBefore _defaultBefore() {
    final c = catalog;
    if (c == null) return const _DefaultBefore('', '', false);
    return _DefaultBefore(
      c.defaultProvider,
      c.defaultModel,
      c.defaultModel.isNotEmpty && c.connected.any((e) => e.isDefault),
    );
  }

  // ---- the key form ----

  KeyFormState? keyForm;
  KeyCheckKind? _formCheck;

  /// Counts "Edit key" presses, for the screen to put focus in the field.
  int keyFocusRequests = 0;

  void openKeyForm(String providerId) {
    final entry = catalog?.byId(providerId);
    _formSeq++;
    _formCheck = null;
    keyForm = KeyFormState(
      providerId: providerId,
      replacing:
          entry?.credentials.any((c) => c.kind == CredentialKind.apiKey) ??
          false,
    );
    _notify();
  }

  /// The form closed (saved, cancelled, App Lock). An answer still on its way
  /// is not applied to a form, and a key that was not sent yet is not sent.
  void closeKeyForm() {
    _formSeq++;
    _formCheck = null;
    if (keyForm == null) return;
    keyForm = null;
    _notify();
  }

  /// The text of the key field changed: a rejection, a provider error, a
  /// refusal or a lost answer gives way to editing, which brings Save back.
  void keyEdited() {
    final form = keyForm;
    if (form == null || form.busy || form.phase == KeyFormPhase.saved) return;
    if (form.phase == KeyFormPhase.editing && !form.emptyKey) return;
    keyForm = form.copyWith(
      phase: KeyFormPhase.editing,
      clearMessage: true,
      emptyKey: false,
    );
    _notify();
  }

  /// "Edit key" after a rejection: nothing is sent; the screen focuses the
  /// field and Save comes back with the first change.
  void editKey() {
    keyFocusRequests++;
    _notify();
  }

  /// What the bar's primary button and Return do now.
  KeyFormAction? primaryKeyAction({required bool hasText}) =>
      keyForm?.primaryAction(hasText: hasText);

  /// Return on a desktop: does the primary action when it is enabled and
  /// says whether it did. "Edit key" sends nothing.
  Future<bool> pressReturn(String text) async {
    final action = primaryKeyAction(hasText: text.isNotEmpty);
    switch (action) {
      case KeyFormAction.save:
        await submitKey(text);
      case KeyFormAction.saveAnyway:
        await saveKeyAnyway(text);
      case KeyFormAction.editKey:
        editKey();
      case null:
        return false;
    }
    return true;
  }

  /// Checks [raw] (trimmed) and saves it. A rejected key or a provider error
  /// is not saved, see [saveKeyAnyway].
  Future<void> submitKey(String raw) => _runKey(raw, forced: false);

  /// "Save anyway" after a rejection or a provider error: saves without
  /// checking again, and the confirmation says the key was not checked.
  Future<void> saveKeyAnyway(String raw) async {
    if (keyForm?.offersSaveAnyway != true) return;
    await _runKey(raw, forced: true);
  }

  Future<void> _runKey(String raw, {required bool forced}) async {
    final form = keyForm;
    if (form == null || form.busy || _disposed) return;
    final key = raw.trim();
    if (key.isEmpty) {
      keyForm = form.copyWith(
        phase: KeyFormPhase.editing,
        emptyKey: true,
        clearMessage: true,
      );
      _notify();
      return;
    }
    final entry = catalog?.byId(form.providerId);
    final keyEnv = entry?.keyEnv;
    if (entry == null || keyEnv == null) {
      keyForm = form.copyWith(phase: KeyFormPhase.refused, clearMessage: true);
      _notify();
      return;
    }
    final generation = _generation;
    final seq = _formSeq;
    bool current() =>
        !_disposed && generation == _generation && seq == _formSeq;
    final span = _signals.start('providers.key.save');
    void finish(KeyCheckKind checked, String outcome) => _signals.end(span, {
      'checked': checked.signal,
      'outcome': outcome,
      'forced': forced,
    });

    KeyCheckKind checked;
    KeyNote? note;
    if (forced) {
      checked = _formCheck ?? KeyCheckKind.rejected;
      note = KeyNote.unchecked;
    } else {
      keyForm = form.copyWith(
        phase: KeyFormPhase.checking,
        clearMessage: true,
        emptyKey: false,
      );
      _notify();
      final check = await repository.checkKey(keyEnv, key);
      if (!current()) {
        finish(_kindOf(check), 'not_saved');
        return;
      }
      checked = _kindOf(check);
      switch (check) {
        case KeyRejected(:final message):
          _formCheck = checked;
          keyForm = keyForm!.copyWith(
            phase: KeyFormPhase.rejected,
            message: message,
          );
          _notify();
          finish(checked, 'not_saved');
          return;
        case KeyProviderError(:final message):
          _formCheck = checked;
          keyForm = keyForm!.copyWith(
            phase: KeyFormPhase.providerError,
            message: message,
          );
          _notify();
          finish(checked, 'not_saved');
          return;
        case KeyUnchecked():
          note = KeyNote.unchecked;
        case KeyUnreachable():
          note = KeyNote.unreachable;
        case KeyAccepted():
          break;
      }
    }

    keyForm = keyForm!.copyWith(
      phase: KeyFormPhase.saving,
      clearMessage: true,
      emptyKey: false,
    );
    _notify();
    final firstKey = !entry.credentials.any(
      (c) => c.kind == CredentialKind.apiKey && c.keyEnv == keyEnv,
    );
    final wasConnected = entry.connected;
    final firstProvider = (catalog?.connected.isEmpty) ?? true;
    final before = _defaultBefore();

    var saved = false;
    var reloaded = false;
    final result = await repository.saveKey(_profile, keyEnv, key);
    switch (result) {
      case KeySaved():
        saved = true;
      case KeyRefused(:final message):
        if (current()) {
          keyForm = keyForm!.copyWith(
            phase: KeyFormPhase.refused,
            message: message,
          );
          _notify();
        }
        finish(checked, 'failed');
        return;
      case KeySaveUnknown():
        // Never resent. The providers are read again: a first key counts as
        // saved when the provider now connects through that variable. Nothing
        // identifies a replacement (the connection looks the same, and the
        // preview can match on its four ends), so a replacement stays unknown.
        if (generation == _generation && !_disposed) {
          reloaded = await _reload();
        }
        final now = generation == _generation && !_disposed
            ? catalog?.byId(entry.id)
            : null;
        saved =
            firstKey &&
            reloaded &&
            now != null &&
            now.connected &&
            now.credentials.any(
              (c) => c.kind == CredentialKind.apiKey && c.keyEnv == keyEnv,
            );
        if (!saved) {
          if (current()) {
            keyForm = keyForm!.copyWith(
              phase: KeyFormPhase.unknown,
              clearMessage: true,
            );
            _notify();
          }
          finish(checked, 'unknown');
          return;
        }
    }

    changes++;
    finish(checked, 'saved');
    if (generation != _generation) {
      _notify();
      return;
    }
    if (!reloaded) await _reload();
    if (_disposed || generation != _generation) return;
    if (!wasConnected) {
      _signals.log('providers.connected', {
        'method': 'key',
        'first': firstProvider,
      });
    }
    if (seq == _formSeq) {
      keyForm = keyForm?.copyWith(phase: KeyFormPhase.saved, note: note);
    }
    _notify();
    // A replacement, or a key for a provider that was connected another way,
    // leaves the default as it is.
    if (!wasConnected) {
      await _runDefaultStep(
        _StepContext(providerId: entry.id, before: before, note: note),
      );
    }
  }

  static KeyCheckKind _kindOf(KeyCheck check) => switch (check) {
    KeyAccepted() => KeyCheckKind.accepted,
    KeyRejected() => KeyCheckKind.rejected,
    KeyProviderError() => KeyCheckKind.providerError,
    KeyUnchecked() => KeyCheckKind.unchecked,
    KeyUnreachable() => KeyCheckKind.unreachable,
  };

  // ---- the default model ----

  DefaultModelStep? step;
  ModelConfirmation? confirmation;
  _StepContext? _stepContext;
  _PendingConfirm? _pendingConfirm;

  /// Closes the step ("Keep &lt;current model&gt;", "Not now", Start chatting).
  /// Nothing is saved.
  void dismissStep() {
    _stepSeq++;
    _stepContext = null;
    if (step == null) return;
    step = null;
    _notify();
  }

  /// Retry on "Hermes is still loading this provider's models".
  Future<void> retryDefaultStep() async {
    final context = _stepContext;
    if (context == null) return;
    await _runDefaultStep(context);
  }

  Future<void> _runDefaultStep(_StepContext context) async {
    if (_disposed) return;
    final generation = _generation;
    final seq = ++_stepSeq;
    bool current() =>
        !_disposed && generation == _generation && seq == _stepSeq;
    _stepContext = context;
    step = DefaultModelStep(
      providerId: context.providerId,
      kind: DefaultStepKind.preparing,
      note: context.note,
    );
    _notify();
    // The recommendation builds its inventory with blocking catalogs, so it
    // also warms the provider's model list for the read that follows.
    final recommended = await repository.recommendedDefault(
      _profile,
      context.providerId,
    );
    if (!current()) return;
    await _reload();
    if (!current()) return;
    final c = catalog;
    final entry = c?.byId(context.providerId);
    final afterModel = c?.defaultModel ?? '';
    final afterProvider = c?.defaultProvider ?? '';
    final before = context.before;

    DefaultModelStep next(
      DefaultStepKind kind, {
      String? model,
      bool moved = false,
    }) => DefaultModelStep(
      providerId: context.providerId,
      kind: kind,
      model: model,
      currentModel: afterModel.isEmpty ? null : afterModel,
      movedByHermes: moved,
      note: context.note,
    );

    if (context.afterSignIn) {
      // The poll's `model` says nothing about whether Hermes moved the
      // default; the snapshot read before the sign-in is compared with the
      // one read after it.
      if (before.model.isNotEmpty && afterModel.isEmpty) {
        step = next(DefaultStepKind.choose);
        _notify();
        return;
      }
      if (afterModel.isNotEmpty &&
          (afterModel != before.model || afterProvider != before.provider)) {
        step = next(DefaultStepKind.saved, model: afterModel, moved: true);
        _notify();
        return;
      }
    }
    if (recommended == null) {
      step = next(DefaultStepKind.choose);
      _notify();
      return;
    }
    if (entry != null && entry.models.isEmpty) {
      step = next(DefaultStepKind.modelsLoading, model: recommended.model);
      _notify();
      return;
    }
    if (!before.usable) {
      // First provider on a profile that could not chat: the recommended
      // model is saved at once.
      step = next(DefaultStepKind.preparing, model: recommended.model);
      _notify();
      await _saveDefault(context.providerId, recommended.model);
      return;
    }
    step = next(DefaultStepKind.ask, model: recommended.model);
    _notify();
  }

  /// Saves [model] of [providerId] as the profile's default: "Use &lt;model&gt;",
  /// "Choose another model…", "Change" and the screen's Default model row. An
  /// expensive model is not saved until [confirmExpensiveModel].
  Future<DefaultSetOutcome> setDefaultModel(String providerId, String model) =>
      _saveDefault(providerId, model);

  Future<DefaultSetOutcome> _saveDefault(
    String providerId,
    String model, {
    bool confirmed = false,
    Span? span,
  }) async {
    if (_disposed) {
      _signals.end(span, {'outcome': 'failed', 'confirm_asked': confirmed});
      return DefaultSetOutcome.failed;
    }
    final generation = _generation;
    final traced = span ?? _signals.start('providers.default_model.set');
    var confirmAsked = confirmed;
    void finish(String outcome) => _signals.end(traced, {
      'outcome': outcome,
      'confirm_asked': confirmAsked,
    });
    final result = await repository.setDefaultModel(
      _profile,
      providerId,
      model,
      confirmExpensive: confirmed,
    );
    if (_disposed) {
      finish('failed');
      return DefaultSetOutcome.failed;
    }
    switch (result) {
      case DefaultModelSaved():
        changes++;
        finish('saved');
        if (generation != _generation) {
          _notify();
          return DefaultSetOutcome.saved;
        }
        confirmation = null;
        _pendingConfirm = null;
        await _reload();
        final open = step;
        if (open != null) {
          step = DefaultModelStep(
            providerId: providerId,
            kind: DefaultStepKind.saved,
            model: model,
            currentModel: open.currentModel,
            note: open.note,
          );
        }
        _notify();
        return DefaultSetOutcome.saved;
      case DefaultModelConfirmRequired(:final message):
        if (generation != _generation) {
          finish('failed');
          return DefaultSetOutcome.failed;
        }
        confirmAsked = true;
        _pendingConfirm = _PendingConfirm(
          providerId,
          model,
          traced,
          generation,
        );
        confirmation = ModelConfirmation(
          providerId: providerId,
          model: model,
          message: message,
        );
        _notify();
        return DefaultSetOutcome.needsConfirmation;
      case DefaultModelRefused() || DefaultModelFailed():
        finish('failed');
        final open = step;
        if (open != null && generation == _generation) {
          step = open.copyWith(
            kind: open.kind == DefaultStepKind.preparing
                ? DefaultStepKind.ask
                : null,
            failed: true,
          );
          _notify();
        }
        return result is DefaultModelRefused
            ? DefaultSetOutcome.refused
            : DefaultSetOutcome.failed;
    }
  }

  /// "Use it anyway": resends with Hermes' confirmation flag. Only this call
  /// ever sends it.
  Future<DefaultSetOutcome> confirmExpensiveModel() async {
    final pending = _pendingConfirm;
    if (pending == null) return DefaultSetOutcome.failed;
    _pendingConfirm = null;
    confirmation = null;
    _notify();
    return _saveDefault(
      pending.providerId,
      pending.model,
      confirmed: true,
      span: pending.span,
    );
  }

  /// Cancel on the confirmation: nothing is saved.
  void declineExpensiveModel() {
    final pending = _pendingConfirm;
    _pendingConfirm = null;
    if (pending != null) {
      _signals.end(pending.span, {
        'outcome': 'declined',
        'confirm_asked': true,
      });
    }
    final open = step;
    if (open != null && open.kind == DefaultStepKind.preparing) {
      step = open.copyWith(kind: DefaultStepKind.ask);
    }
    if (confirmation == null) return;
    confirmation = null;
    _notify();
  }

  // ---- removing ----

  /// What the latest removal came to, for the detail's "Still connected
  /// through N other saved credentials".
  RemovalResult? lastRemoval;

  /// Removes what [action] says from [entry]. A 404 counts as already
  /// removed; a lost answer re-reads the providers and is never resent.
  Future<RemovalResult> remove(
    ProviderEntry entry,
    RemovalAction action,
  ) async {
    final kind = action.kind;
    if (kind == null) {
      return RemovalResult(
        providerId: entry.id,
        kind: null,
        status: RemovalStatus.refused,
      );
    }
    if (_disposed) {
      return RemovalResult(
        providerId: entry.id,
        kind: kind,
        status: RemovalStatus.unknown,
      );
    }
    final generation = _generation;
    final span = _signals.start('providers.remove');
    final result = switch (action) {
      RemoveKeyAction(:final keyEnv) => await repository.removeKey(
        _profile,
        keyEnv,
      ),
      SignOutAction() => await repository.signOut(_profile, entry.id),
      DeleteEndpointAction() => await repository.deleteEndpoint(
        _profile,
        entry.id,
      ),
      ServerCommandAction() => const RemoveRefused(null),
    };

    var status = switch (result) {
      Removed() => RemovalStatus.removed,
      AlreadyGone() => RemovalStatus.alreadyGone,
      RemoveRefused() => RemovalStatus.refused,
      RemoveUnknown() => RemovalStatus.unknown,
    };
    final message = result is RemoveRefused ? result.message : null;
    if (status == RemovalStatus.refused) {
      return _removalDone(
        span,
        entry,
        kind,
        status,
        generation,
        message: message,
      );
    }
    var reloaded = false;
    if (generation == _generation) reloaded = await _reload();
    if (status == RemovalStatus.unknown && reloaded) {
      // The re-read can prove the credential is gone.
      final now = catalog?.byId(entry.id);
      final gone = switch (action) {
        RemoveKeyAction(:final keyEnv) =>
          now == null ||
              !now.credentials.any(
                (c) => c.kind == CredentialKind.apiKey && c.keyEnv == keyEnv,
              ),
        SignOutAction() => now == null || now.account == null,
        DeleteEndpointAction() => now == null,
        ServerCommandAction() => false,
      };
      if (gone) status = RemovalStatus.removed;
    }
    if (status != RemovalStatus.unknown) changes++;
    return _removalDone(
      span,
      entry,
      kind,
      status,
      generation,
      stillConnected: generation == _generation
          ? catalog?.byId(entry.id)
          : null,
    );
  }

  RemovalResult _removalDone(
    Span? span,
    ProviderEntry entry,
    RemovalKind kind,
    RemovalStatus status,
    int generation, {
    String? message,
    ProviderEntry? stillConnected,
  }) {
    _signals.end(span, {
      'kind': kind.name,
      'outcome': switch (status) {
        RemovalStatus.removed => 'removed',
        RemovalStatus.alreadyGone => 'already_gone',
        RemovalStatus.refused => 'refused',
        RemovalStatus.unknown => 'unknown',
      },
    });
    final connected =
        stillConnected != null &&
        stillConnected.connected &&
        (status == RemovalStatus.removed ||
            status == RemovalStatus.alreadyGone);
    final result = RemovalResult(
      providerId: entry.id,
      kind: kind,
      status: status,
      message: message,
      stillConnected: connected,
      stillConnectedThrough: connected ? stillConnected.credentials.length : 0,
    );
    if (!_disposed && generation == _generation) {
      lastRemoval = result;
      _notify();
    }
    return result;
  }

  // ---- custom endpoints ----

  EndpointFormState endpointForm = const EndpointFormState();

  /// A new endpoint form, or one for editing.
  void resetEndpointForm() {
    _endpointSeq++;
    endpointForm = const EndpointFormState();
    _notify();
  }

  /// The address, name or key changed: a check made for the old values no
  /// longer applies.
  void endpointEdited() {
    if (endpointForm.busy) return;
    if (endpointForm.phase == EndpointFormPhase.idle &&
        endpointForm.issue == null) {
      return;
    }
    endpointForm = EndpointFormState(
      phase: endpointForm.phase == EndpointFormPhase.saved
          ? EndpointFormPhase.saved
          : EndpointFormPhase.idle,
      models: endpointForm.models,
      resolvedBaseUrl: endpointForm.resolvedBaseUrl,
      warning: endpointForm.warning,
      checkedAddress: endpointForm.checkedAddress,
    );
    _notify();
  }

  /// Asks the server to probe [address]. Nothing is saved; [apiKey] only
  /// travels in the request.
  Future<void> checkEndpoint({
    required String name,
    required String address,
    String? apiKey,
    String? apiMode,
    String model = '',
  }) async {
    if (endpointForm.busy || _disposed) return;
    final typed = address.trim();
    final issue = _addressIssue(typed);
    if (issue != null) {
      endpointForm = EndpointFormState(issue: issue);
      _notify();
      return;
    }
    final seq = ++_endpointSeq;
    final generation = _generation;
    endpointForm = EndpointFormState(
      phase: EndpointFormPhase.checking,
      checkedAddress: typed,
    );
    _notify();
    // A key is not sent to an unencrypted address that is not local to the
    // server: the check would put it on the wire before anyone confirmed.
    final keyNotSent =
        apiKey != null &&
        apiKey.isNotEmpty &&
        endpointSendsKeyUnencrypted(typed, hasKey: true);
    final span = _signals.start('providers.endpoint.check');
    final result = await repository.checkEndpoint(
      name: name.trim(),
      baseUrl: typed,
      model: model.trim(),
      apiKey: keyNotSent ? null : apiKey,
      apiMode: apiMode,
    );
    final models = result is EndpointChecked ? result.models.length : 0;
    _signals.end(span, {
      'outcome': switch (result) {
        EndpointChecked(:final warning) =>
          warning != null || models == 0 ? 'warning' : 'models',
        EndpointUnreachable() => 'unreachable',
        EndpointCheckFailed() => 'failed',
      },
      'models': ProviderSignals.bucket(models),
    });
    if (_disposed || seq != _endpointSeq || generation != _generation) return;
    endpointForm = switch (result) {
      EndpointChecked(:final models, :final resolvedBaseUrl, :final warning) =>
        EndpointFormState(
          phase: EndpointFormPhase.checked,
          models: models,
          resolvedBaseUrl: resolvedBaseUrl != typed ? resolvedBaseUrl : null,
          warning: warning,
          checkedAddress: typed,
          keyNotSent: keyNotSent,
        ),
      EndpointUnreachable() => EndpointFormState(
        phase: EndpointFormPhase.unreachable,
        checkedAddress: typed,
        keyNotSent: keyNotSent,
      ),
      EndpointCheckFailed() => EndpointFormState(
        phase: EndpointFormPhase.checkFailed,
        checkedAddress: typed,
        keyNotSent: keyNotSent,
      ),
    };
    _notify();
  }

  static EndpointIssue? _addressIssue(String address) {
    if (address.isEmpty) return EndpointIssue.addressMissing;
    final uri = Uri.tryParse(address);
    final ok =
        uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
    return ok ? null : EndpointIssue.addressScheme;
  }

  /// Saves the endpoint. [apiKey] null leaves a saved key alone (the field was
  /// not touched), `''` clears it (after [confirmedClear]), anything else
  /// replaces it. The address saved is the one Hermes resolved in the last
  /// check of this very address. `make_default` goes with the first usable
  /// default, or when [useForNewChats] is set.
  Future<EndpointSubmit> saveEndpoint({
    String? id,
    required String name,
    required String address,
    required String model,
    String? apiKey,
    String? apiMode,
    bool useForNewChats = false,
    bool confirmedClear = false,
    bool confirmedCleartext = false,
  }) async {
    if (endpointForm.busy || _disposed) return EndpointSubmit.invalid;
    final typed = address.trim();
    final issue = name.trim().isEmpty
        ? EndpointIssue.nameMissing
        : _addressIssue(typed) ??
              (model.trim().isEmpty ? EndpointIssue.modelMissing : null);
    if (issue != null) {
      endpointForm = EndpointFormState(
        phase: endpointForm.phase,
        models: endpointForm.models,
        resolvedBaseUrl: endpointForm.resolvedBaseUrl,
        warning: endpointForm.warning,
        checkedAddress: endpointForm.checkedAddress,
        issue: issue,
      );
      _notify();
      return EndpointSubmit.invalid;
    }
    if (apiKey != null && apiKey.isEmpty && !confirmedClear) {
      return EndpointSubmit.needsClearConfirmation;
    }
    // The address Hermes resolved counts only for a check of this very
    // address; the confirmation looks at what is actually sent.
    final fresh = endpointForm.checkedAddress == typed;
    final baseUrl = fresh ? endpointForm.resolvedBaseUrl ?? typed : typed;
    if (!confirmedCleartext &&
        endpointSendsKeyUnencrypted(
          baseUrl,
          hasKey: apiKey != null && apiKey.isNotEmpty,
        )) {
      return EndpointSubmit.needsCleartextConfirmation;
    }
    final models = fresh && endpointForm.models.isNotEmpty
        ? endpointForm.models
        : null;
    final generation = _generation;
    final seq = ++_endpointSeq;
    final wasEmpty = (catalog?.connected.isEmpty) ?? true;
    final makeDefault = !_defaultBefore().usable || useForNewChats;
    final previous = endpointForm;
    endpointForm = EndpointFormState(
      phase: EndpointFormPhase.saving,
      models: previous.models,
      resolvedBaseUrl: previous.resolvedBaseUrl,
      warning: previous.warning,
      checkedAddress: previous.checkedAddress,
    );
    _notify();
    final span = _signals.start('providers.endpoint.save');
    final result = await repository.saveEndpoint(
      _profile,
      id: id,
      name: name.trim(),
      baseUrl: baseUrl,
      model: model.trim(),
      apiKey: apiKey,
      apiMode: apiMode,
      makeDefault: makeDefault ? true : null,
      models: models,
    );
    void finish(String outcome) => _signals.end(span, {
      'outcome': outcome,
      'made_default': makeDefault,
      'edit': id != null,
    });
    final live = !_disposed && generation == _generation && seq == _endpointSeq;
    switch (result) {
      case EndpointRefused(:final message):
        finish('refused');
        if (live) {
          endpointForm = EndpointFormState(
            phase: EndpointFormPhase.refused,
            models: previous.models,
            resolvedBaseUrl: previous.resolvedBaseUrl,
            warning: previous.warning,
            checkedAddress: previous.checkedAddress,
            message: message,
          );
          _notify();
        }
        return EndpointSubmit.refused;
      case EndpointSaveUnknown():
        // Never resent: the providers are read again and the person looks.
        finish('unknown');
        if (generation == _generation) await _reload();
        if (!_disposed && generation == _generation && seq == _endpointSeq) {
          endpointForm = const EndpointFormState(
            phase: EndpointFormPhase.unknown,
          );
          _notify();
        }
        return EndpointSubmit.unknown;
      case EndpointSaved(id: final savedId):
        finish('saved');
        changes++;
        if (generation != _generation) {
          _notify();
          return EndpointSubmit.saved;
        }
        await _reload();
        if (_disposed) return EndpointSubmit.saved;
        if (id == null) {
          _signals.log('providers.connected', {
            'method': 'endpoint',
            'first': wasEmpty,
          });
        }
        if (seq == _endpointSeq) {
          endpointForm = const EndpointFormState(
            phase: EndpointFormPhase.saved,
          );
        }
        final endpointId = savedId ?? id;
        if (endpointId != null && (makeDefault || id == null)) {
          // Built from what the re-read says, not from what was asked.
          final slug = 'custom:$endpointId';
          final taken =
              catalog?.byId(endpointId)?.isDefault == true &&
              defaultModel.isNotEmpty;
          step = taken
              ? DefaultModelStep(
                  providerId: slug,
                  kind: DefaultStepKind.saved,
                  model: defaultModel,
                  currentModel: defaultModel,
                )
              : DefaultModelStep(
                  providerId: slug,
                  kind: DefaultStepKind.ask,
                  model: model.trim(),
                  currentModel: defaultModel.isEmpty ? null : defaultModel,
                );
        }
        _notify();
        return EndpointSubmit.saved;
    }
  }

  // ---- account sign-ins ----

  final _signIns = <String, ProviderSignIn>{};
  final _signInContexts = <ProviderSignIn, _SignInContext>{};

  static String _signInKey(String? profile, String providerId) =>
      '${profile ?? ''}\u0000$providerId';

  /// The sign-in of [providerId] for the shown profile, pending or ended and
  /// not dismissed yet.
  ProviderSignIn? signInFor(String providerId) =>
      _signIns[_signInKey(_profile, providerId)];

  /// The shown profile's sign-ins that still wait ("Waiting for sign-in…").
  List<ProviderSignIn> get pendingSignIns => [
    for (final s in _signIns.values)
      if (s.profile == _profile && s.pending) s,
  ];

  /// Starts the device-code sign-in of [providerId] for the shown profile, or
  /// returns the one already going ("Continue"). The default as the snapshot
  /// reads it now is kept to compare with the one read after an approval.
  ProviderSignIn startSignIn(String providerId) {
    final key = _signInKey(_profile, providerId);
    final existing = _signIns[key];
    if (existing != null && existing.pending) return existing;
    if (existing != null) _forget(key, existing);
    final signIn = ProviderSignIn(
      repository: repository,
      profile: _profile,
      providerId: providerId,
      platform: _platform,
      onEnded: _signInEnded,
    );
    _signIns[key] = signIn;
    _signInContexts[signIn] = _SignInContext(
      before: _defaultBefore(),
      first: (catalog?.connected.isEmpty) ?? true,
    );
    signIn.addListener(_notify);
    unawaited(signIn.start());
    _notify();
    return signIn;
  }

  /// Stop on a pending sign-in, after the person confirmed: the server's
  /// poller is told to stop, so a later approval saves nothing.
  Future<void> cancelSignIn(String providerId) async {
    await signInFor(providerId)?.cancel();
  }

  /// Drops an ended sign-in once its result was shown.
  void dismissSignIn(String providerId) {
    final key = _signInKey(_profile, providerId);
    final signIn = _signIns[key];
    if (signIn == null || signIn.pending) return;
    _forget(key, signIn);
    _notify();
  }

  void _forget(String key, ProviderSignIn signIn) {
    _signIns.remove(key);
    _signInContexts.remove(signIn);
    signIn.removeListener(_notify);
    signIn.dispose();
  }

  Future<void> _signInEnded(ProviderSignIn signIn) async {
    if (_disposed || signIn.phase != SignInPhase.approved) return;
    final context = _signInContexts[signIn];
    changes++;
    if (signIn.profile != _profile || context == null) {
      _notify();
      return;
    }
    _signals.log('providers.connected', {
      'method': 'account',
      'first': context.first,
    });
    _notify();
    await _runDefaultStep(
      _StepContext(
        providerId: signIn.providerId,
        before: context.before,
        afterSignIn: true,
      ),
    );
  }

  // ---- lifecycle ----

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    for (final signIn in _signIns.values.toList()) {
      signIn.appLifecycle(state);
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// The screen closed, or the user signed out or changed server: sign-ins
  /// stop polling without being cancelled, and nothing typed is kept (the
  /// controller never held it).
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    for (final signIn in _signIns.values) {
      signIn.removeListener(_notify);
      signIn.dispose();
    }
    _signIns.clear();
    _signInContexts.clear();
    final pending = _pendingConfirm;
    if (pending != null) {
      _signals.end(pending.span, {
        'outcome': 'declined',
        'confirm_asked': true,
      });
      _pendingConfirm = null;
    }
    super.dispose();
  }

  @override
  String toString() => 'ProviderSetupController';
}
