import 'dart:async';

import 'package:hermes_app/src/live_activities/live_activity_service.dart';

/// One activity as the fake iOS sees it.
class FakeActivity {
  FakeActivity(this.id, this.data, this.staleIn);

  final String id;
  Map<String, Object> data;
  Duration staleIn;
  int updates = 0;

  /// Set when it was ended: immediately (`null` date) or with a dismissal.
  bool ended = false;
  DateTime? dismissAt;

  String get state => data['state']! as String;
  String get title => data['title']! as String;
}

/// A [LiveActivityService] that records what the app asked of ActivityKit.
class FakeLiveActivityService implements LiveActivityService {
  final activities = <FakeActivity>[];
  bool allow = true;
  bool refuse = false;
  int endAllCalls = 0;
  Uri? launch;
  final _taps = StreamController<Uri>.broadcast();

  List<FakeActivity> get running => activities.where((a) => !a.ended).toList();

  void tap(Uri uri) => _taps.add(uri);

  FakeActivity _find(String id) => activities.lastWhere((a) => a.id == id);

  @override
  Future<void> init() async {}

  @override
  Future<bool> allowed() async => allow;

  @override
  Future<bool> start(
    String id,
    Map<String, Object> data,
    Duration staleIn,
  ) async {
    if (refuse || !allow) return false;
    activities.add(FakeActivity(id, data, staleIn));
    return true;
  }

  @override
  Future<void> update(
    String id,
    Map<String, Object> data,
    Duration staleIn,
  ) async {
    final activity = _find(id);
    activity
      ..data = data
      ..staleIn = staleIn
      ..updates += 1;
  }

  @override
  Future<void> endAt(String id, DateTime dismissAt) async {
    _find(id)
      ..ended = true
      ..dismissAt = dismissAt;
  }

  @override
  Future<void> endNow(String id) async {
    _find(id)
      ..ended = true
      ..dismissAt = null;
  }

  @override
  Future<void> endAll() async {
    endAllCalls++;
    for (final activity in activities) {
      if (!activity.ended) activity.ended = true;
    }
  }

  @override
  Stream<Uri> get taps => _taps.stream;

  @override
  Future<Uri?> launchTap() async {
    final uri = launch;
    launch = null;
    return uri;
  }
}
