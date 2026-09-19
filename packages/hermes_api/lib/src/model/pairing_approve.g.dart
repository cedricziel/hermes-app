// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pairing_approve.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PairingApproveCWProxy {
  PairingApprove platform(String platform);

  PairingApprove code(String? code);

  PairingApprove requestId(String? requestId);

  PairingApprove profile(String? profile);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PairingApprove(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PairingApprove(...).copyWith(id: 12, name: "My name")
  /// ````
  PairingApprove call({
    String platform,
    String? code,
    String? requestId,
    String? profile,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPairingApprove.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPairingApprove.copyWith.fieldName(...)`
class _$PairingApproveCWProxyImpl implements _$PairingApproveCWProxy {
  const _$PairingApproveCWProxyImpl(this._value);

  final PairingApprove _value;

  @override
  PairingApprove platform(String platform) => this(platform: platform);

  @override
  PairingApprove code(String? code) => this(code: code);

  @override
  PairingApprove requestId(String? requestId) => this(requestId: requestId);

  @override
  PairingApprove profile(String? profile) => this(profile: profile);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PairingApprove(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PairingApprove(...).copyWith(id: 12, name: "My name")
  /// ````
  PairingApprove call({
    Object? platform = const $CopyWithPlaceholder(),
    Object? code = const $CopyWithPlaceholder(),
    Object? requestId = const $CopyWithPlaceholder(),
    Object? profile = const $CopyWithPlaceholder(),
  }) {
    return PairingApprove(
      platform: platform == const $CopyWithPlaceholder()
          ? _value.platform
          // ignore: cast_nullable_to_non_nullable
          : platform as String,
      code: code == const $CopyWithPlaceholder()
          ? _value.code
          // ignore: cast_nullable_to_non_nullable
          : code as String?,
      requestId: requestId == const $CopyWithPlaceholder()
          ? _value.requestId
          // ignore: cast_nullable_to_non_nullable
          : requestId as String?,
      profile: profile == const $CopyWithPlaceholder()
          ? _value.profile
          // ignore: cast_nullable_to_non_nullable
          : profile as String?,
    );
  }
}

extension $PairingApproveCopyWith on PairingApprove {
  /// Returns a callable class that can be used as follows: `instanceOfPairingApprove.copyWith(...)` or like so:`instanceOfPairingApprove.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PairingApproveCWProxy get copyWith => _$PairingApproveCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PairingApprove _$PairingApproveFromJson(Map<String, dynamic> json) =>
    $checkedCreate('PairingApprove', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['platform']);
      final val = PairingApprove(
        platform: $checkedConvert('platform', (v) => v as String),
        code: $checkedConvert('code', (v) => v as String? ?? ''),
        requestId: $checkedConvert('request_id', (v) => v as String? ?? ''),
        profile: $checkedConvert('profile', (v) => v as String?),
      );
      return val;
    }, fieldKeyMap: const {'requestId': 'request_id'});

Map<String, dynamic> _$PairingApproveToJson(PairingApprove instance) =>
    <String, dynamic>{
      'platform': instance.platform,
      'code': ?instance.code,
      'request_id': ?instance.requestId,
      'profile': ?instance.profile,
    };
