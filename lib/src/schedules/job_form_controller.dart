import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

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
class JobFormController extends ChangeNotifier {
  JobFormController({
    required this.repository,
    this.editing,
    String? profile,
    DateTime Function()? now,
  }) : draft = editing != null
           ? JobDraft.fromJob(editing)
           : (JobDraft()..profile = profile),
       _baseline = editing != null
           ? JobDraft.fromJob(editing)
           : (JobDraft()..profile = profile),
       _now = now ?? DateTime.now;

  final HermesCronRepository repository;

  /// The job being changed, or null for a new one.
  final CronJob? editing;
  final JobDraft draft;
  final DateTime Function() _now;
  final JobDraft _baseline;

  bool _whenTouched = false;
  bool _saving = false;
  String? _error;
  List<DeliveryTarget> _targets = const [
    DeliveryTarget(id: 'local', name: 'Local (save only)'),
  ];
  bool _targetsFailed = false;

  DateTime get now => _now();
  bool get isEditing => editing != null;
  bool get saving => _saving;
  String? get error => _error;
  bool get whenTouched => _whenTouched;
  bool get targetsFailed => _targetsFailed;

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

  /// Tells the form that a field changed, so a save that failed can be
  /// tried again and the dirty state is recomputed.
  void changed({bool when = false}) {
    if (when) _whenTouched = true;
    _error = null;
    notifyListeners();
  }

  Future<void> loadTargets() async {
    try {
      final loaded = await repository.deliveryTargets();
      if (loaded.isNotEmpty) _targets = loaded;
      _targetsFailed = false;
    } on Object {
      _targetsFailed = true;
    }
    notifyListeners();
  }

  /// Saves the job. Null when it was refused or is not ready; [error] says
  /// why. A save already in progress is not repeated.
  Future<CronJob?> save() async {
    if (_saving) return null;
    final problem = draft.validate(_now());
    if (problem != null) {
      _error = problem;
      notifyListeners();
      return null;
    }
    _saving = true;
    _error = null;
    notifyListeners();
    try {
      final job = editing == null
          ? await repository.createJob(draft, profile: draft.profile)
          : await repository.updateJob(
              editing!.id,
              draft.diff(_baseline, whenTouched: _whenTouched),
              profile: editing!.profile,
            );
      _saving = false;
      notifyListeners();
      return job;
    } on Object catch (e) {
      _saving = false;
      _error = describeSaveFailure(e);
      notifyListeners();
      return null;
    }
  }
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
