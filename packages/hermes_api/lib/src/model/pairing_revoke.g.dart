// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pairing_revoke.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PairingRevokeCWProxy {
  PairingRevoke platform(String platform);

  PairingRevoke userId(String userId);

  PairingRevoke profile(String? profile);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `PairingRevoke(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// PairingRevoke(...).copyWith(id: 12, name: "My name")
  /// ```
  PairingRevoke call({String platform, String userId, String? profile});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfPairingRevoke.copyWith(...)` or call `instanceOfPairingRevoke.copyWith.fieldName(value)` for a single field.
class _$PairingRevokeCWProxyImpl implements _$PairingRevokeCWProxy {
  const _$PairingRevokeCWProxyImpl(this._value);

  final PairingRevoke _value;

  @override
  PairingRevoke platform(String platform) => call(platform: platform);

  @override
  PairingRevoke userId(String userId) => call(userId: userId);

  @override
  PairingRevoke profile(String? profile) => call(profile: profile);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `PairingRevoke(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// PairingRevoke(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  PairingRevoke call({
    Object? platform = const $CopyWithPlaceholder(),
    Object? userId = const $CopyWithPlaceholder(),
    Object? profile = const $CopyWithPlaceholder(),
  }) {
    return PairingRevoke(
      platform: platform == const $CopyWithPlaceholder() || platform == null
          ? _value.platform
          // ignore: cast_nullable_to_non_nullable
          : platform as String,
      userId: userId == const $CopyWithPlaceholder() || userId == null
          ? _value.userId
          // ignore: cast_nullable_to_non_nullable
          : userId as String,
      profile: profile == const $CopyWithPlaceholder()
          ? _value.profile
          // ignore: cast_nullable_to_non_nullable
          : profile as String?,
    );
  }
}

extension $PairingRevokeCopyWith on PairingRevoke {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfPairingRevoke.copyWith(...)` or `instanceOfPairingRevoke.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PairingRevokeCWProxy get copyWith => _$PairingRevokeCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PairingRevoke _$PairingRevokeFromJson(Map<String, dynamic> json) =>
    $checkedCreate('PairingRevoke', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['platform', 'user_id']);
      final val = PairingRevoke(
        platform: $checkedConvert('platform', (v) => v as String),
        userId: $checkedConvert('user_id', (v) => v as String),
        profile: $checkedConvert('profile', (v) => v as String?),
      );
      return val;
    }, fieldKeyMap: const {'userId': 'user_id'});

Map<String, dynamic> _$PairingRevokeToJson(PairingRevoke instance) =>
    <String, dynamic>{
      'platform': instance.platform,
      'user_id': instance.userId,
      'profile': ?instance.profile,
    };
