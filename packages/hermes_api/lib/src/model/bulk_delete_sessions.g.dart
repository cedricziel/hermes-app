// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bulk_delete_sessions.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$BulkDeleteSessionsCWProxy {
  BulkDeleteSessions ids(List<String> ids);

  BulkDeleteSessions profile(String? profile);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BulkDeleteSessions(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BulkDeleteSessions(...).copyWith(id: 12, name: "My name")
  /// ````
  BulkDeleteSessions call({List<String> ids, String? profile});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfBulkDeleteSessions.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfBulkDeleteSessions.copyWith.fieldName(...)`
class _$BulkDeleteSessionsCWProxyImpl implements _$BulkDeleteSessionsCWProxy {
  const _$BulkDeleteSessionsCWProxyImpl(this._value);

  final BulkDeleteSessions _value;

  @override
  BulkDeleteSessions ids(List<String> ids) => this(ids: ids);

  @override
  BulkDeleteSessions profile(String? profile) => this(profile: profile);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BulkDeleteSessions(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BulkDeleteSessions(...).copyWith(id: 12, name: "My name")
  /// ````
  BulkDeleteSessions call({
    Object? ids = const $CopyWithPlaceholder(),
    Object? profile = const $CopyWithPlaceholder(),
  }) {
    return BulkDeleteSessions(
      ids: ids == const $CopyWithPlaceholder()
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
  /// Returns a callable class that can be used as follows: `instanceOfBulkDeleteSessions.copyWith(...)` or like so:`instanceOfBulkDeleteSessions.copyWith.fieldName(...)`.
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
