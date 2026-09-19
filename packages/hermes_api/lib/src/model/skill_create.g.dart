// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'skill_create.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SkillCreateCWProxy {
  SkillCreate name(String name);

  SkillCreate content(String content);

  SkillCreate category(String? category);

  SkillCreate profile(String? profile);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SkillCreate(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SkillCreate(...).copyWith(id: 12, name: "My name")
  /// ````
  SkillCreate call({
    String name,
    String content,
    String? category,
    String? profile,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfSkillCreate.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfSkillCreate.copyWith.fieldName(...)`
class _$SkillCreateCWProxyImpl implements _$SkillCreateCWProxy {
  const _$SkillCreateCWProxyImpl(this._value);

  final SkillCreate _value;

  @override
  SkillCreate name(String name) => this(name: name);

  @override
  SkillCreate content(String content) => this(content: content);

  @override
  SkillCreate category(String? category) => this(category: category);

  @override
  SkillCreate profile(String? profile) => this(profile: profile);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SkillCreate(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SkillCreate(...).copyWith(id: 12, name: "My name")
  /// ````
  SkillCreate call({
    Object? name = const $CopyWithPlaceholder(),
    Object? content = const $CopyWithPlaceholder(),
    Object? category = const $CopyWithPlaceholder(),
    Object? profile = const $CopyWithPlaceholder(),
  }) {
    return SkillCreate(
      name: name == const $CopyWithPlaceholder()
          ? _value.name
          // ignore: cast_nullable_to_non_nullable
          : name as String,
      content: content == const $CopyWithPlaceholder()
          ? _value.content
          // ignore: cast_nullable_to_non_nullable
          : content as String,
      category: category == const $CopyWithPlaceholder()
          ? _value.category
          // ignore: cast_nullable_to_non_nullable
          : category as String?,
      profile: profile == const $CopyWithPlaceholder()
          ? _value.profile
          // ignore: cast_nullable_to_non_nullable
          : profile as String?,
    );
  }
}

extension $SkillCreateCopyWith on SkillCreate {
  /// Returns a callable class that can be used as follows: `instanceOfSkillCreate.copyWith(...)` or like so:`instanceOfSkillCreate.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$SkillCreateCWProxy get copyWith => _$SkillCreateCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SkillCreate _$SkillCreateFromJson(Map<String, dynamic> json) =>
    $checkedCreate('SkillCreate', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['name', 'content']);
      final val = SkillCreate(
        name: $checkedConvert('name', (v) => v as String),
        content: $checkedConvert('content', (v) => v as String),
        category: $checkedConvert('category', (v) => v as String?),
        profile: $checkedConvert('profile', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$SkillCreateToJson(SkillCreate instance) =>
    <String, dynamic>{
      'name': instance.name,
      'content': instance.content,
      'category': ?instance.category,
      'profile': ?instance.profile,
    };
