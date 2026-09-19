// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'skill_content_update.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SkillContentUpdateCWProxy {
  SkillContentUpdate name(String name);

  SkillContentUpdate content(String content);

  SkillContentUpdate profile(String? profile);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SkillContentUpdate(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SkillContentUpdate(...).copyWith(id: 12, name: "My name")
  /// ````
  SkillContentUpdate call({String name, String content, String? profile});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfSkillContentUpdate.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfSkillContentUpdate.copyWith.fieldName(...)`
class _$SkillContentUpdateCWProxyImpl implements _$SkillContentUpdateCWProxy {
  const _$SkillContentUpdateCWProxyImpl(this._value);

  final SkillContentUpdate _value;

  @override
  SkillContentUpdate name(String name) => this(name: name);

  @override
  SkillContentUpdate content(String content) => this(content: content);

  @override
  SkillContentUpdate profile(String? profile) => this(profile: profile);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SkillContentUpdate(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SkillContentUpdate(...).copyWith(id: 12, name: "My name")
  /// ````
  SkillContentUpdate call({
    Object? name = const $CopyWithPlaceholder(),
    Object? content = const $CopyWithPlaceholder(),
    Object? profile = const $CopyWithPlaceholder(),
  }) {
    return SkillContentUpdate(
      name: name == const $CopyWithPlaceholder()
          ? _value.name
          // ignore: cast_nullable_to_non_nullable
          : name as String,
      content: content == const $CopyWithPlaceholder()
          ? _value.content
          // ignore: cast_nullable_to_non_nullable
          : content as String,
      profile: profile == const $CopyWithPlaceholder()
          ? _value.profile
          // ignore: cast_nullable_to_non_nullable
          : profile as String?,
    );
  }
}

extension $SkillContentUpdateCopyWith on SkillContentUpdate {
  /// Returns a callable class that can be used as follows: `instanceOfSkillContentUpdate.copyWith(...)` or like so:`instanceOfSkillContentUpdate.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$SkillContentUpdateCWProxy get copyWith =>
      _$SkillContentUpdateCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SkillContentUpdate _$SkillContentUpdateFromJson(Map<String, dynamic> json) =>
    $checkedCreate('SkillContentUpdate', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['name', 'content']);
      final val = SkillContentUpdate(
        name: $checkedConvert('name', (v) => v as String),
        content: $checkedConvert('content', (v) => v as String),
        profile: $checkedConvert('profile', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$SkillContentUpdateToJson(SkillContentUpdate instance) =>
    <String, dynamic>{
      'name': instance.name,
      'content': instance.content,
      'profile': ?instance.profile,
    };
