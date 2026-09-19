// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'skill_uninstall_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SkillUninstallRequestCWProxy {
  SkillUninstallRequest name(String name);

  SkillUninstallRequest profile(String? profile);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SkillUninstallRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SkillUninstallRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  SkillUninstallRequest call({String name, String? profile});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfSkillUninstallRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfSkillUninstallRequest.copyWith.fieldName(...)`
class _$SkillUninstallRequestCWProxyImpl
    implements _$SkillUninstallRequestCWProxy {
  const _$SkillUninstallRequestCWProxyImpl(this._value);

  final SkillUninstallRequest _value;

  @override
  SkillUninstallRequest name(String name) => this(name: name);

  @override
  SkillUninstallRequest profile(String? profile) => this(profile: profile);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SkillUninstallRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SkillUninstallRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  SkillUninstallRequest call({
    Object? name = const $CopyWithPlaceholder(),
    Object? profile = const $CopyWithPlaceholder(),
  }) {
    return SkillUninstallRequest(
      name: name == const $CopyWithPlaceholder()
          ? _value.name
          // ignore: cast_nullable_to_non_nullable
          : name as String,
      profile: profile == const $CopyWithPlaceholder()
          ? _value.profile
          // ignore: cast_nullable_to_non_nullable
          : profile as String?,
    );
  }
}

extension $SkillUninstallRequestCopyWith on SkillUninstallRequest {
  /// Returns a callable class that can be used as follows: `instanceOfSkillUninstallRequest.copyWith(...)` or like so:`instanceOfSkillUninstallRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$SkillUninstallRequestCWProxy get copyWith =>
      _$SkillUninstallRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SkillUninstallRequest _$SkillUninstallRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('SkillUninstallRequest', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['name']);
  final val = SkillUninstallRequest(
    name: $checkedConvert('name', (v) => v as String),
    profile: $checkedConvert('profile', (v) => v as String?),
  );
  return val;
});

Map<String, dynamic> _$SkillUninstallRequestToJson(
  SkillUninstallRequest instance,
) => <String, dynamic>{'name': instance.name, 'profile': ?instance.profile};
