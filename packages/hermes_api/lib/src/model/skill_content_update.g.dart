// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'skill_content_update.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SkillContentUpdateCWProxy {
  SkillContentUpdate name(String name);

  SkillContentUpdate content(String content);

  SkillContentUpdate profile(String? profile);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `SkillContentUpdate(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// SkillContentUpdate(...).copyWith(id: 12, name: "My name")
  /// ```
  SkillContentUpdate call({String name, String content, String? profile});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfSkillContentUpdate.copyWith(...)` or call `instanceOfSkillContentUpdate.copyWith.fieldName(value)` for a single field.
class _$SkillContentUpdateCWProxyImpl implements _$SkillContentUpdateCWProxy {
  const _$SkillContentUpdateCWProxyImpl(this._value);

  final SkillContentUpdate _value;

  @override
  SkillContentUpdate name(String name) => call(name: name);

  @override
  SkillContentUpdate content(String content) => call(content: content);

  @override
  SkillContentUpdate profile(String? profile) => call(profile: profile);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `SkillContentUpdate(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// SkillContentUpdate(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  SkillContentUpdate call({
    Object? name = const $CopyWithPlaceholder(),
    Object? content = const $CopyWithPlaceholder(),
    Object? profile = const $CopyWithPlaceholder(),
  }) {
    return SkillContentUpdate(
      name: name == const $CopyWithPlaceholder() || name == null
          ? _value.name
          // ignore: cast_nullable_to_non_nullable
          : name as String,
      content: content == const $CopyWithPlaceholder() || content == null
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
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfSkillContentUpdate.copyWith(...)` or `instanceOfSkillContentUpdate.copyWith.fieldName(...)`.
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
