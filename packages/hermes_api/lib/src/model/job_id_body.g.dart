// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'job_id_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$JobIdBodyCWProxy {
  JobIdBody jobId(String jobId);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `JobIdBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// JobIdBody(...).copyWith(id: 12, name: "My name")
  /// ````
  JobIdBody call({String jobId});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfJobIdBody.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfJobIdBody.copyWith.fieldName(...)`
class _$JobIdBodyCWProxyImpl implements _$JobIdBodyCWProxy {
  const _$JobIdBodyCWProxyImpl(this._value);

  final JobIdBody _value;

  @override
  JobIdBody jobId(String jobId) => this(jobId: jobId);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `JobIdBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// JobIdBody(...).copyWith(id: 12, name: "My name")
  /// ````
  JobIdBody call({Object? jobId = const $CopyWithPlaceholder()}) {
    return JobIdBody(
      jobId: jobId == const $CopyWithPlaceholder()
          ? _value.jobId
          // ignore: cast_nullable_to_non_nullable
          : jobId as String,
    );
  }
}

extension $JobIdBodyCopyWith on JobIdBody {
  /// Returns a callable class that can be used as follows: `instanceOfJobIdBody.copyWith(...)` or like so:`instanceOfJobIdBody.copyWith.fieldName(...)`.
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
