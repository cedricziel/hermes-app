// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'skills_update_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SkillsUpdateRequestCWProxy {
  SkillsUpdateRequest profile(String? profile);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `SkillsUpdateRequest(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// SkillsUpdateRequest(...).copyWith(id: 12, name: "My name")
  /// ```
  SkillsUpdateRequest call({String? profile});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfSkillsUpdateRequest.copyWith(...)` or call `instanceOfSkillsUpdateRequest.copyWith.fieldName(value)` for a single field.
class _$SkillsUpdateRequestCWProxyImpl implements _$SkillsUpdateRequestCWProxy {
  const _$SkillsUpdateRequestCWProxyImpl(this._value);

  final SkillsUpdateRequest _value;

  @override
  SkillsUpdateRequest profile(String? profile) => call(profile: profile);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `SkillsUpdateRequest(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// SkillsUpdateRequest(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  SkillsUpdateRequest call({Object? profile = const $CopyWithPlaceholder()}) {
    return SkillsUpdateRequest(
      profile: profile == const $CopyWithPlaceholder()
          ? _value.profile
          // ignore: cast_nullable_to_non_nullable
          : profile as String?,
    );
  }
}

extension $SkillsUpdateRequestCopyWith on SkillsUpdateRequest {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfSkillsUpdateRequest.copyWith(...)` or `instanceOfSkillsUpdateRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$SkillsUpdateRequestCWProxy get copyWith =>
      _$SkillsUpdateRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SkillsUpdateRequest _$SkillsUpdateRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate('SkillsUpdateRequest', json, ($checkedConvert) {
      final val = SkillsUpdateRequest(
        profile: $checkedConvert('profile', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$SkillsUpdateRequestToJson(
  SkillsUpdateRequest instance,
) => <String, dynamic>{'profile': ?instance.profile};
