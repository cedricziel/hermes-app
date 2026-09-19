// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'skill_install_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SkillInstallRequestCWProxy {
  SkillInstallRequest identifier(String identifier);

  SkillInstallRequest profile(String? profile);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SkillInstallRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SkillInstallRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  SkillInstallRequest call({String identifier, String? profile});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfSkillInstallRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfSkillInstallRequest.copyWith.fieldName(...)`
class _$SkillInstallRequestCWProxyImpl implements _$SkillInstallRequestCWProxy {
  const _$SkillInstallRequestCWProxyImpl(this._value);

  final SkillInstallRequest _value;

  @override
  SkillInstallRequest identifier(String identifier) =>
      this(identifier: identifier);

  @override
  SkillInstallRequest profile(String? profile) => this(profile: profile);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SkillInstallRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SkillInstallRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  SkillInstallRequest call({
    Object? identifier = const $CopyWithPlaceholder(),
    Object? profile = const $CopyWithPlaceholder(),
  }) {
    return SkillInstallRequest(
      identifier: identifier == const $CopyWithPlaceholder()
          ? _value.identifier
          // ignore: cast_nullable_to_non_nullable
          : identifier as String,
      profile: profile == const $CopyWithPlaceholder()
          ? _value.profile
          // ignore: cast_nullable_to_non_nullable
          : profile as String?,
    );
  }
}

extension $SkillInstallRequestCopyWith on SkillInstallRequest {
  /// Returns a callable class that can be used as follows: `instanceOfSkillInstallRequest.copyWith(...)` or like so:`instanceOfSkillInstallRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$SkillInstallRequestCWProxy get copyWith =>
      _$SkillInstallRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SkillInstallRequest _$SkillInstallRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate('SkillInstallRequest', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['identifier']);
      final val = SkillInstallRequest(
        identifier: $checkedConvert('identifier', (v) => v as String),
        profile: $checkedConvert('profile', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$SkillInstallRequestToJson(
  SkillInstallRequest instance,
) => <String, dynamic>{
  'identifier': instance.identifier,
  'profile': ?instance.profile,
};
