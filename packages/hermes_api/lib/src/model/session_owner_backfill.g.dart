// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_owner_backfill.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SessionOwnerBackfillCWProxy {
  SessionOwnerBackfill profile(String? profile);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SessionOwnerBackfill(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SessionOwnerBackfill(...).copyWith(id: 12, name: "My name")
  /// ````
  SessionOwnerBackfill call({String? profile});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfSessionOwnerBackfill.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfSessionOwnerBackfill.copyWith.fieldName(...)`
class _$SessionOwnerBackfillCWProxyImpl
    implements _$SessionOwnerBackfillCWProxy {
  const _$SessionOwnerBackfillCWProxyImpl(this._value);

  final SessionOwnerBackfill _value;

  @override
  SessionOwnerBackfill profile(String? profile) => this(profile: profile);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SessionOwnerBackfill(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SessionOwnerBackfill(...).copyWith(id: 12, name: "My name")
  /// ````
  SessionOwnerBackfill call({Object? profile = const $CopyWithPlaceholder()}) {
    return SessionOwnerBackfill(
      profile: profile == const $CopyWithPlaceholder()
          ? _value.profile
          // ignore: cast_nullable_to_non_nullable
          : profile as String?,
    );
  }
}

extension $SessionOwnerBackfillCopyWith on SessionOwnerBackfill {
  /// Returns a callable class that can be used as follows: `instanceOfSessionOwnerBackfill.copyWith(...)` or like so:`instanceOfSessionOwnerBackfill.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$SessionOwnerBackfillCWProxy get copyWith =>
      _$SessionOwnerBackfillCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SessionOwnerBackfill _$SessionOwnerBackfillFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('SessionOwnerBackfill', json, ($checkedConvert) {
  final val = SessionOwnerBackfill(
    profile: $checkedConvert('profile', (v) => v as String?),
  );
  return val;
});

Map<String, dynamic> _$SessionOwnerBackfillToJson(
  SessionOwnerBackfill instance,
) => <String, dynamic>{'profile': ?instance.profile};
