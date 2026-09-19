// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'skills_update_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SkillsUpdateRequestCWProxy {
  SkillsUpdateRequest profile(String? profile);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SkillsUpdateRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SkillsUpdateRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  SkillsUpdateRequest call({String? profile});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfSkillsUpdateRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfSkillsUpdateRequest.copyWith.fieldName(...)`
class _$SkillsUpdateRequestCWProxyImpl implements _$SkillsUpdateRequestCWProxy {
  const _$SkillsUpdateRequestCWProxyImpl(this._value);

  final SkillsUpdateRequest _value;

  @override
  SkillsUpdateRequest profile(String? profile) => this(profile: profile);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SkillsUpdateRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SkillsUpdateRequest(...).copyWith(id: 12, name: "My name")
  /// ````
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
  /// Returns a callable class that can be used as follows: `instanceOfSkillsUpdateRequest.copyWith(...)` or like so:`instanceOfSkillsUpdateRequest.copyWith.fieldName(...)`.
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
