// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_owner_backfill.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SessionOwnerBackfillCWProxy {
  SessionOwnerBackfill profile(String? profile);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `SessionOwnerBackfill(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// SessionOwnerBackfill(...).copyWith(id: 12, name: "My name")
  /// ```
  SessionOwnerBackfill call({String? profile});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfSessionOwnerBackfill.copyWith(...)` or call `instanceOfSessionOwnerBackfill.copyWith.fieldName(value)` for a single field.
class _$SessionOwnerBackfillCWProxyImpl
    implements _$SessionOwnerBackfillCWProxy {
  const _$SessionOwnerBackfillCWProxyImpl(this._value);

  final SessionOwnerBackfill _value;

  @override
  SessionOwnerBackfill profile(String? profile) => call(profile: profile);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `SessionOwnerBackfill(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// SessionOwnerBackfill(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
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
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfSessionOwnerBackfill.copyWith(...)` or `instanceOfSessionOwnerBackfill.copyWith.fieldName(...)`.
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
