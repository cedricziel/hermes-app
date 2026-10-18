// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'skill_uninstall_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SkillUninstallRequestCWProxy {
  SkillUninstallRequest name(String name);

  SkillUninstallRequest profile(String? profile);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `SkillUninstallRequest(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// SkillUninstallRequest(...).copyWith(id: 12, name: "My name")
  /// ```
  SkillUninstallRequest call({String name, String? profile});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfSkillUninstallRequest.copyWith(...)` or call `instanceOfSkillUninstallRequest.copyWith.fieldName(value)` for a single field.
class _$SkillUninstallRequestCWProxyImpl
    implements _$SkillUninstallRequestCWProxy {
  const _$SkillUninstallRequestCWProxyImpl(this._value);

  final SkillUninstallRequest _value;

  @override
  SkillUninstallRequest name(String name) => call(name: name);

  @override
  SkillUninstallRequest profile(String? profile) => call(profile: profile);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `SkillUninstallRequest(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// SkillUninstallRequest(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  SkillUninstallRequest call({
    Object? name = const $CopyWithPlaceholder(),
    Object? profile = const $CopyWithPlaceholder(),
  }) {
    return SkillUninstallRequest(
      name: name == const $CopyWithPlaceholder() || name == null
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
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfSkillUninstallRequest.copyWith(...)` or `instanceOfSkillUninstallRequest.copyWith.fieldName(...)`.
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
