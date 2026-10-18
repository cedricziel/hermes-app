// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cron_job_update.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CronJobUpdateCWProxy {
  CronJobUpdate updates(Map<String, Object> updates);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `CronJobUpdate(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// CronJobUpdate(...).copyWith(id: 12, name: "My name")
  /// ```
  CronJobUpdate call({Map<String, Object> updates});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfCronJobUpdate.copyWith(...)` or call `instanceOfCronJobUpdate.copyWith.fieldName(value)` for a single field.
class _$CronJobUpdateCWProxyImpl implements _$CronJobUpdateCWProxy {
  const _$CronJobUpdateCWProxyImpl(this._value);

  final CronJobUpdate _value;

  @override
  CronJobUpdate updates(Map<String, Object> updates) => call(updates: updates);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `CronJobUpdate(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// CronJobUpdate(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  CronJobUpdate call({Object? updates = const $CopyWithPlaceholder()}) {
    return CronJobUpdate(
      updates: updates == const $CopyWithPlaceholder() || updates == null
          ? _value.updates
          // ignore: cast_nullable_to_non_nullable
          : updates as Map<String, Object>,
    );
  }
}

extension $CronJobUpdateCopyWith on CronJobUpdate {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfCronJobUpdate.copyWith(...)` or `instanceOfCronJobUpdate.copyWith.fieldName(...)`.
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
