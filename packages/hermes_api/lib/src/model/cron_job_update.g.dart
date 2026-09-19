// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cron_job_update.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CronJobUpdateCWProxy {
  CronJobUpdate updates(Map<String, Object> updates);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CronJobUpdate(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CronJobUpdate(...).copyWith(id: 12, name: "My name")
  /// ````
  CronJobUpdate call({Map<String, Object> updates});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCronJobUpdate.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCronJobUpdate.copyWith.fieldName(...)`
class _$CronJobUpdateCWProxyImpl implements _$CronJobUpdateCWProxy {
  const _$CronJobUpdateCWProxyImpl(this._value);

  final CronJobUpdate _value;

  @override
  CronJobUpdate updates(Map<String, Object> updates) => this(updates: updates);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CronJobUpdate(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CronJobUpdate(...).copyWith(id: 12, name: "My name")
  /// ````
  CronJobUpdate call({Object? updates = const $CopyWithPlaceholder()}) {
    return CronJobUpdate(
      updates: updates == const $CopyWithPlaceholder()
          ? _value.updates
          // ignore: cast_nullable_to_non_nullable
          : updates as Map<String, Object>,
    );
  }
}

extension $CronJobUpdateCopyWith on CronJobUpdate {
  /// Returns a callable class that can be used as follows: `instanceOfCronJobUpdate.copyWith(...)` or like so:`instanceOfCronJobUpdate.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CronJobUpdateCWProxy get copyWith => _$CronJobUpdateCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CronJobUpdate _$CronJobUpdateFromJson(Map<String, dynamic> json) =>
    $checkedCreate('CronJobUpdate', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['updates']);
      final val = CronJobUpdate(
        updates: $checkedConvert(
          'updates',
          (v) => (v as Map<String, dynamic>).map(
            (k, e) => MapEntry(k, e as Object),
          ),
        ),
      );
      return val;
    });

Map<String, dynamic> _$CronJobUpdateToJson(CronJobUpdate instance) =>
    <String, dynamic>{'updates': instance.updates};
