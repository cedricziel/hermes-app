import 'package:dio/dio.dart';
import 'package:hermes_api/hermes_api.dart';

import 'schedule_models.dart';

/// The server refused a cron request and said why (`{"detail": "..."}`).
class CronException implements Exception {
  const CronException(this.message, {this.status});

  final String message;
  final int? status;

  bool get isNotFound => status == 404;

  @override
  String toString() => message;
}

Future<T> _guard<T>(Future<T> Function() run) async {
  try {
    return await run();
  } on DioException catch (e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    final detail = data is Map ? data['detail'] : null;
    if (detail is String) throw CronException(detail, status: status);
    if (detail is List && detail.isNotEmpty && detail.first is Map) {
      final message = (detail.first as Map)['msg'];
      if (message is String) throw CronException(message, status: status);
    }
    if (status != null) {
      throw CronException('The server answered $status', status: status);
    }
    rethrow;
  }
}

/// Reads and changes the dashboard's scheduled tasks through the generated
/// [DefaultApi].
///
/// The cron routes declare no response schema, so bodies are parsed by hand
/// into the models in `schedule_models.dart`, skipping rows that don't fit.
class HermesCronRepository {
  HermesCronRepository(this._api);

  final DefaultApi _api;

  /// Whether the server has the cron routes. Any failure, including a server
  /// too old to have them, reads as no: the app never offers a feature it
  /// cannot confirm.
  Future<bool> isAvailable() async {
    try {
      await _api.getCronDeliveryTargetsApiCronDeliveryTargetsGet();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// The jobs of [profile], or of every profile for `all`.
  Future<List<CronJob>> listJobs({String? profile}) => _guard(() async {
    final response = await _api.listCronJobsApiCronJobsGet(profile: profile);
    final data = response.data;
    if (data is! List) return const <CronJob>[];
    return [for (final row in data) ?CronJob.fromJson(row)];
  });

  Future<CronJob> getJob(String id, {String? profile}) => _guard(() async {
    final response = await _api.getCronJobApiCronJobsJobIdGet(
      jobId: id,
      profile: profile,
    );
    final job = CronJob.fromJson(response.data);
    if (job == null) throw const CronException('Unreadable job', status: 502);
    return job;
  });

  Future<void> pause(String id, {String? profile}) => _guard(
    () =>
        _api.pauseCronJobApiCronJobsJobIdPausePost(jobId: id, profile: profile),
  );

  Future<void> resume(String id, {String? profile}) => _guard(
    () => _api.resumeCronJobApiCronJobsJobIdResumePost(
      jobId: id,
      profile: profile,
    ),
  );

  Future<void> trigger(String id, {String? profile}) => _guard(
    () => _api.triggerCronJobApiCronJobsJobIdTriggerPost(
      jobId: id,
      profile: profile,
    ),
  );

  Future<void> delete(String id, {String? profile}) => _guard(
    () => _api.deleteCronJobApiCronJobsJobIdDelete(jobId: id, profile: profile),
  );

  Future<List<CronRun>> listRuns(
    String id, {
    String? profile,
    int limit = 20,
  }) => _guard(() async {
    final response = await _api.listCronJobRunsApiCronJobsJobIdRunsGet(
      jobId: id,
      profile: profile,
      limit: limit,
    );
    final data = response.data;
    final rows = data is Map ? data['runs'] : null;
    if (rows is! List) return const <CronRun>[];
    return [for (final row in rows) ?CronRun.fromJson(row)];
  });

  Future<List<DeliveryTarget>> deliveryTargets() => _guard(() async {
    final response = await _api
        .getCronDeliveryTargetsApiCronDeliveryTargetsGet();
    final data = response.data;
    final rows = data is Map ? data['targets'] : null;
    if (rows is! List) return const <DeliveryTarget>[];
    return [for (final row in rows) ?DeliveryTarget.fromJson(row)];
  });
}
