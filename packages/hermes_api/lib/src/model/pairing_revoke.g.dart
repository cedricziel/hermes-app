// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pairing_revoke.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PairingRevokeCWProxy {
  PairingRevoke platform(String platform);

  PairingRevoke userId(String userId);

  PairingRevoke profile(String? profile);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PairingRevoke(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PairingRevoke(...).copyWith(id: 12, name: "My name")
  /// ````
  PairingRevoke call({String platform, String userId, String? profile});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPairingRevoke.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPairingRevoke.copyWith.fieldName(...)`
class _$PairingRevokeCWProxyImpl implements _$PairingRevokeCWProxy {
  const _$PairingRevokeCWProxyImpl(this._value);

  final PairingRevoke _value;

  @override
  PairingRevoke platform(String platform) => this(platform: platform);

  @override
  PairingRevoke userId(String userId) => this(userId: userId);

  @override
  PairingRevoke profile(String? profile) => this(profile: profile);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PairingRevoke(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PairingRevoke(...).copyWith(id: 12, name: "My name")
  /// ````
  PairingRevoke call({
    Object? platform = const $CopyWithPlaceholder(),
    Object? userId = const $CopyWithPlaceholder(),
    Object? profile = const $CopyWithPlaceholder(),
  }) {
    return PairingRevoke(
      platform: platform == const $CopyWithPlaceholder()
          ? _value.platform
          // ignore: cast_nullable_to_non_nullable
          : platform as String,
      userId: userId == const $CopyWithPlaceholder()
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
  /// Returns a callable class that can be used as follows: `instanceOfPairingRevoke.copyWith(...)` or like so:`instanceOfPairingRevoke.copyWith.fieldName(...)`.
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
