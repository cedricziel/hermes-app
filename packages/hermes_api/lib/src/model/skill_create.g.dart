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

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `SkillCreate(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// SkillCreate(...).copyWith(id: 12, name: "My name")
  /// ```
  SkillCreate call({
    String name,
    String content,
    String? category,
    String? profile,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfSkillCreate.copyWith(...)` or call `instanceOfSkillCreate.copyWith.fieldName(value)` for a single field.
class _$SkillCreateCWProxyImpl implements _$SkillCreateCWProxy {
  const _$SkillCreateCWProxyImpl(this._value);

  final SkillCreate _value;

  @override
  SkillCreate name(String name) => call(name: name);

  @override
  SkillCreate content(String content) => call(content: content);

  @override
  SkillCreate category(String? category) => call(category: category);

  @override
  SkillCreate profile(String? profile) => call(profile: profile);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `SkillCreate(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// SkillCreate(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  SkillCreate call({
    Object? name = const $CopyWithPlaceholder(),
    Object? content = const $CopyWithPlaceholder(),
    Object? category = const $CopyWithPlaceholder(),
    Object? profile = const $CopyWithPlaceholder(),
  }) {
    return SkillCreate(
      name: name == const $CopyWithPlaceholder() || name == null
          ? _value.name
          // ignore: cast_nullable_to_non_nullable
          : name as String,
      content: content == const $CopyWithPlaceholder() || content == null
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
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfSkillCreate.copyWith(...)` or `instanceOfSkillCreate.copyWith.fieldName(...)`.
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
