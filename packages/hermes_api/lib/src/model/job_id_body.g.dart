// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'job_id_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$JobIdBodyCWProxy {
  JobIdBody jobId(String jobId);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `JobIdBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// JobIdBody(...).copyWith(id: 12, name: "My name")
  /// ```
  JobIdBody call({String jobId});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfJobIdBody.copyWith(...)` or call `instanceOfJobIdBody.copyWith.fieldName(value)` for a single field.
class _$JobIdBodyCWProxyImpl implements _$JobIdBodyCWProxy {
  const _$JobIdBodyCWProxyImpl(this._value);

  final JobIdBody _value;

  @override
  JobIdBody jobId(String jobId) => call(jobId: jobId);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `JobIdBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// JobIdBody(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  JobIdBody call({Object? jobId = const $CopyWithPlaceholder()}) {
    return JobIdBody(
      jobId: jobId == const $CopyWithPlaceholder() || jobId == null
          ? _value.jobId
          // ignore: cast_nullable_to_non_nullable
          : jobId as String,
    );
  }
}

extension $JobIdBodyCopyWith on JobIdBody {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfJobIdBody.copyWith(...)` or `instanceOfJobIdBody.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$JobIdBodyCWProxy get copyWith => _$JobIdBodyCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

JobIdBody _$JobIdBodyFromJson(Map<String, dynamic> json) => $checkedCreate(
  'JobIdBody',
  json,
  ($checkedConvert) {
    $checkKeys(json, requiredKeys: const ['job_id']);
    final val = JobIdBody(jobId: $checkedConvert('job_id', (v) => v as String));
    return val;
  },
  fieldKeyMap: const {'jobId': 'job_id'},
);

Map<String, dynamic> _$JobIdBodyToJson(JobIdBody instance) => <String, dynamic>{
  'job_id': instance.jobId,
};
