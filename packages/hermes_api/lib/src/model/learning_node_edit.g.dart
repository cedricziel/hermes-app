// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'learning_node_edit.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$LearningNodeEditCWProxy {
  LearningNodeEdit id(String id);

  LearningNodeEdit content(String content);

  LearningNodeEdit profile(String? profile);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `LearningNodeEdit(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// LearningNodeEdit(...).copyWith(id: 12, name: "My name")
  /// ```
  LearningNodeEdit call({String id, String content, String? profile});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfLearningNodeEdit.copyWith(...)` or call `instanceOfLearningNodeEdit.copyWith.fieldName(value)` for a single field.
class _$LearningNodeEditCWProxyImpl implements _$LearningNodeEditCWProxy {
  const _$LearningNodeEditCWProxyImpl(this._value);

  final LearningNodeEdit _value;

  @override
  LearningNodeEdit id(String id) => call(id: id);

  @override
  LearningNodeEdit content(String content) => call(content: content);

  @override
  LearningNodeEdit profile(String? profile) => call(profile: profile);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `LearningNodeEdit(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// LearningNodeEdit(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  LearningNodeEdit call({
    Object? id = const $CopyWithPlaceholder(),
    Object? content = const $CopyWithPlaceholder(),
    Object? profile = const $CopyWithPlaceholder(),
  }) {
    return LearningNodeEdit(
      id: id == const $CopyWithPlaceholder() || id == null
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
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

extension $LearningNodeEditCopyWith on LearningNodeEdit {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfLearningNodeEdit.copyWith(...)` or `instanceOfLearningNodeEdit.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$LearningNodeEditCWProxy get copyWith => _$LearningNodeEditCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LearningNodeEdit _$LearningNodeEditFromJson(Map<String, dynamic> json) =>
    $checkedCreate('LearningNodeEdit', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['id', 'content']);
      final val = LearningNodeEdit(
        id: $checkedConvert('id', (v) => v as String),
        content: $checkedConvert('content', (v) => v as String),
        profile: $checkedConvert('profile', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$LearningNodeEditToJson(LearningNodeEdit instance) =>
    <String, dynamic>{
      'id': instance.id,
      'content': instance.content,
      'profile': ?instance.profile,
    };
