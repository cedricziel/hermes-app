import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/safe_notifier.dart';
import '../models/hermes_models_repository.dart';
import '../models/model_provider_option.dart';
import 'hermes_cron_repository.dart';
import 'job_draft.dart';
import 'schedule_models.dart';

String describeSaveFailure(Object e) => switch (e) {
  CronException(:final message) => message,
  DioException(:final response) when response?.statusCode != null =>
    'The server answered ${response!.statusCode}',
  _ => 'Could not reach the server',
};

/// State of the job form, for a new job or for changing [editing]. It
/// guards against a second save while one runs, and keeps the values and the
/// server's reason when a save is refused.
class JobFormController extends ChangeNotifier with SafeNotifier {
  JobFormController({
    required this.repository,
    this.editing,
    this.activity,
    String? profile,
    DateTime Function()? now,
  }) : draft = editing != null
           ? JobDraft.fromJob(editing)
           : (JobDraft()..profile = profile),
       _baseline = editing != null
           ? JobDraft.fromJob(editing)
           : (JobDraft()..profile = profile),
       _now = now ?? DateTime.now {
    _lastDeliveredActivity = activity?.value ?? true;
    activity?.addListener(_activityChanged);
  }

  final HermesCronRepository repository;

  /// The authorization window for protected reads and saves, when supplied.
  final ValueListenable<bool>? activity;

  /// The job being changed, or null for a new one.
  final CronJob? editing;
  final JobDraft draft;
  final DateTime Function() _now;
  final JobDraft _baseline;
  HermesModelsRepository? _modelsRepository;

  bool _whenTouched = false;
  bool _saving = false;
  bool _lastDeliveredActivity = true;
  int _activityEpoch = 0;
  String? _error;
  List<DeliveryTarget> _targets = const [
    DeliveryTarget(id: 'local', name: 'Local (save only)'),
  ];
  bool _targetsFailed = false;
  int _targetsLoad = 0;
  ModelOptions? _modelOptions;
  int _modelsLoad = 0;

  DateTime get now => _now();
  bool get isEditing => editing != null;
  bool get saving => _saving;

  /// Whether protected form work may currently be started.
  bool get active => !disposed && (activity?.value ?? true);
  String? get error => _error;
  bool get whenTouched => _whenTouched;
  bool get targetsFailed => _targetsFailed;

  /// The models of the job's profile; null while loading or unavailable.
  ModelOptions? get modelOptions => _modelOptions;

  /// The server's targets, plus the one the job already has when the server
  /// no longer lists it.
  List<DeliveryTarget> get targets {
    final stored = draft.deliver;
    if (_targets.any((t) => t.id == stored)) return _targets;
    return [
      ..._targets,
      DeliveryTarget(id: stored, name: '$stored (unavailable)'),
    ];
  }

  DeliveryTarget? get selectedTarget =>
      targets.where((t) => t.id == draft.deliver).firstOrNull;

  /// Whether leaving would lose something the user entered.
  bool get isDirty =>
      _whenTouched ||
      draft.paused != _baseline.paused ||
      draft.profile != _baseline.profile ||
      draft.diff(_baseline, whenTouched: false).isNotEmpty;

  bool _currentActivity(int epoch) => active && epoch == _activityEpoch;

  bool _notifyFor(int epoch) {
    if (!_currentActivity(epoch)) return false;
    notifyListeners();
    return _currentActivity(epoch);
  }

  void _notifyIfActive() {
    final epoch = _activityEpoch;
    _notifyFor(epoch);
  }

  void _activityChanged() {
    if (disposed) return;
    final next = activity?.value ?? true;
    final changed = next != _lastDeliveredActivity;
    _lastDeliveredActivity = next;
    final epoch = ++_activityEpoch;
    _targetsLoad++;
    _modelsLoad++;
    if (changed) {
      notifyListeners();
      if (!_currentActivity(epoch)) return;
    }
    if (next) {
      scheduleMicrotask(() {
        if (!_currentActivity(epoch)) return;
        unawaited(loadTargets());
        final models = _modelsRepository;
        if (models != null) unawaited(loadModels(models));
      });
    }
  }

  /// Tells the form that a field changed, so a save that failed can be
  /// tried again and the dirty state is recomputed.
  void changed({bool when = false}) {
    if (when) _whenTouched = true;
    _error = null;
    notifyListeners();
  }

  /// Loads the delivery targets of the draft's profile. A load that a newer
  /// one overtook is dropped.
  Future<void> loadTargets() async {
    if (!active) return;
    final epoch = _activityEpoch;
    final load = ++_targetsLoad;
    try {
      final loaded = await repository.deliveryTargets(profile: draft.profile);
      if (!_currentActivity(epoch) || load != _targetsLoad) return;
      if (loaded.isNotEmpty) _targets = loaded;
      _targetsFailed = false;
    } on Object {
      if (!_currentActivity(epoch) || load != _targetsLoad) return;
      _targetsFailed = true;
    }
    _notifyFor(epoch);
  }

  /// Loads the models of the draft's profile. A load that a newer one
  /// overtook is dropped.
  Future<void> loadModels(HermesModelsRepository models) async {
    _modelsRepository = models;
    if (!active) return;
    final epoch = _activityEpoch;
    final load = ++_modelsLoad;
    _modelOptions = null;
    if (!_notifyFor(epoch)) return;
    final options = await models
        .load(profile: draft.profile)
        .then<ModelOptions?>((o) => o, onError: (Object _) => null);
    if (!_currentActivity(epoch) || load != _modelsLoad) return;
    _modelOptions = options;
    _notifyFor(epoch);
  }

  /// Saves the job. Null when it was refused or is not ready; [error] says
  /// why. A save already in progress is not repeated.
  Future<CronJob?> save() async {
    if (!active) throw const JobFormActivityCancelled();
    if (_saving) return null;
    final epoch = _activityEpoch;
    final problem = draft.validate(_now());
    if (problem != null) {
      _error = problem;
      if (!_notifyFor(epoch)) throw const JobFormActivityCancelled();
      return null;
    }
    _saving = true;
    _error = null;
    if (!_notifyFor(epoch)) {
      _saving = false;
      _notifyIfActive();
      throw const JobFormActivityCancelled();
    }
    var released = false;
    try {
      final job = editing == null
          ? await repository.createJob(draft, profile: draft.profile)
          : await repository.updateJob(
              editing!.id,
              draft.diff(_baseline, whenTouched: _whenTouched),
              profile: editing!.profile,
            );
      if (!_currentActivity(epoch)) {
        throw const JobFormActivityCancelled();
      }
      _saving = false;
      released = true;
      if (!_notifyFor(epoch)) throw const JobFormActivityCancelled();
      return job;
    } on JobFormActivityCancelled {
      if (!released) {
        _saving = false;
        released = true;
        _notifyIfActive();
      }
      rethrow;
    } on Object catch (e) {
      if (!_currentActivity(epoch)) {
        _saving = false;
        released = true;
        _notifyIfActive();
        throw const JobFormActivityCancelled();
      }
      _saving = false;
      released = true;
      _error = describeSaveFailure(e);
      if (!_notifyFor(epoch)) {
        _error = null;
        throw const JobFormActivityCancelled();
      }
      return null;
    }
  }

  @override
  void dispose() {
    activity?.removeListener(_activityChanged);
    _activityEpoch++;
    _targetsLoad++;
    _modelsLoad++;
    super.dispose();
  }
}

/// A protected form operation could not commit in its starting activity epoch.
class JobFormActivityCancelled implements Exception {
  const JobFormActivityCancelled();
}

/// State of a blueprint's form: the values of its slots, the server's
/// answer to them and the same double-save guard.
class BlueprintFormController extends ChangeNotifier {
  BlueprintFormController({
    required this.repository,
    required this.blueprint,
    this.profile,
  }) {
    for (final field in blueprint.fields) {
      final value = field.defaultValue;
      if (value != null && value.toString().isNotEmpty) {
        values[field.name] = value.toString();
      }
    }
  }

  final HermesCronRepository repository;
  final Blueprint blueprint;
  final String? profile;

  /// What the user has filled in, by slot name.
  final values = <String, Object>{};
  final fieldErrors = <String, String>{};
  String? _error;
  bool _saving = false;

  bool get saving => _saving;
  String? get error => _error;

  void set(String name, String value) {
    if (value.trim().isEmpty) {
      values.remove(name);
    } else {
      values[name] = value.trim();
    }
    fieldErrors.remove(name);
    _error = null;
    notifyListeners();
  }

  Future<CronJob?> save() async {
    if (_saving) return null;
    final missing = [
      for (final f in blueprint.fields)
        if (!f.optional && !values.containsKey(f.name)) f,
    ];
    fieldErrors.clear();
    if (missing.isNotEmpty) {
      for (final f in missing) {
        fieldErrors[f.name] = 'Required';
      }
      notifyListeners();
      return null;
    }
    _saving = true;
    _error = null;
    notifyListeners();
    try {
      final job = await repository.instantiate(
        blueprint.key,
        values,
        profile: profile,
      );
      _saving = false;
      notifyListeners();
      return job;
    } on Object catch (e) {
      _saving = false;
      final message = describeSaveFailure(e);
      final field = e is CronException && e.status == 422
          ? blueprint.fieldIn(message)
          : null;
      if (field != null) {
        fieldErrors[field.name] = message;
      } else {
        _error = message;
      }
      notifyListeners();
      return null;
    }
  }
}
