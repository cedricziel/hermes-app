// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bulk_delete_sessions.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$BulkDeleteSessionsCWProxy {
  BulkDeleteSessions ids(List<String> ids);

  BulkDeleteSessions profile(String? profile);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `BulkDeleteSessions(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// BulkDeleteSessions(...).copyWith(id: 12, name: "My name")
  /// ```
  BulkDeleteSessions call({List<String> ids, String? profile});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfBulkDeleteSessions.copyWith(...)` or call `instanceOfBulkDeleteSessions.copyWith.fieldName(value)` for a single field.
class _$BulkDeleteSessionsCWProxyImpl implements _$BulkDeleteSessionsCWProxy {
  const _$BulkDeleteSessionsCWProxyImpl(this._value);

  final BulkDeleteSessions _value;

  @override
  BulkDeleteSessions ids(List<String> ids) => call(ids: ids);

  @override
  BulkDeleteSessions profile(String? profile) => call(profile: profile);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `BulkDeleteSessions(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// BulkDeleteSessions(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  BulkDeleteSessions call({
    Object? ids = const $CopyWithPlaceholder(),
    Object? profile = const $CopyWithPlaceholder(),
  }) {
    return BulkDeleteSessions(
      ids: ids == const $CopyWithPlaceholder() || ids == null
          ? _value.ids
          // ignore: cast_nullable_to_non_nullable
          : ids as List<String>,
      profile: profile == const $CopyWithPlaceholder()
          ? _value.profile
          // ignore: cast_nullable_to_non_nullable
          : profile as String?,
    );
  }
}

extension $BulkDeleteSessionsCopyWith on BulkDeleteSessions {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfBulkDeleteSessions.copyWith(...)` or `instanceOfBulkDeleteSessions.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$BulkDeleteSessionsCWProxy get copyWith =>
      _$BulkDeleteSessionsCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BulkDeleteSessions _$BulkDeleteSessionsFromJson(Map<String, dynamic> json) =>
    $checkedCreate('BulkDeleteSessions', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['ids']);
      final val = BulkDeleteSessions(
        ids: $checkedConvert(
          'ids',
          (v) => (v as List<dynamic>).map((e) => e as String).toList(),
        ),
        profile: $checkedConvert('profile', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$BulkDeleteSessionsToJson(BulkDeleteSessions instance) =>
    <String, dynamic>{'ids': instance.ids, 'profile': ?instance.profile};
