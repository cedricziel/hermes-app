// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'skill_install_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SkillInstallRequestCWProxy {
  SkillInstallRequest identifier(String identifier);

  SkillInstallRequest profile(String? profile);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `SkillInstallRequest(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// SkillInstallRequest(...).copyWith(id: 12, name: "My name")
  /// ```
  SkillInstallRequest call({String identifier, String? profile});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfSkillInstallRequest.copyWith(...)` or call `instanceOfSkillInstallRequest.copyWith.fieldName(value)` for a single field.
class _$SkillInstallRequestCWProxyImpl implements _$SkillInstallRequestCWProxy {
  const _$SkillInstallRequestCWProxyImpl(this._value);

  final SkillInstallRequest _value;

  @override
  SkillInstallRequest identifier(String identifier) =>
      call(identifier: identifier);

  @override
  SkillInstallRequest profile(String? profile) => call(profile: profile);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `SkillInstallRequest(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// SkillInstallRequest(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  SkillInstallRequest call({
    Object? identifier = const $CopyWithPlaceholder(),
    Object? profile = const $CopyWithPlaceholder(),
  }) {
    return SkillInstallRequest(
      identifier:
          identifier == const $CopyWithPlaceholder() || identifier == null
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
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfSkillInstallRequest.copyWith(...)` or `instanceOfSkillInstallRequest.copyWith.fieldName(...)`.
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
