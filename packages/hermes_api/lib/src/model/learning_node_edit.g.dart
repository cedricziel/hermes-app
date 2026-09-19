// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'learning_node_edit.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$LearningNodeEditCWProxy {
  LearningNodeEdit id(String id);

  LearningNodeEdit content(String content);

  LearningNodeEdit profile(String? profile);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `LearningNodeEdit(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// LearningNodeEdit(...).copyWith(id: 12, name: "My name")
  /// ````
  LearningNodeEdit call({String id, String content, String? profile});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfLearningNodeEdit.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfLearningNodeEdit.copyWith.fieldName(...)`
class _$LearningNodeEditCWProxyImpl implements _$LearningNodeEditCWProxy {
  const _$LearningNodeEditCWProxyImpl(this._value);

  final LearningNodeEdit _value;

  @override
  LearningNodeEdit id(String id) => this(id: id);

  @override
  LearningNodeEdit content(String content) => this(content: content);

  @override
  LearningNodeEdit profile(String? profile) => this(profile: profile);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `LearningNodeEdit(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// LearningNodeEdit(...).copyWith(id: 12, name: "My name")
  /// ````
  LearningNodeEdit call({
    Object? id = const $CopyWithPlaceholder(),
    Object? content = const $CopyWithPlaceholder(),
    Object? profile = const $CopyWithPlaceholder(),
  }) {
    return LearningNodeEdit(
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
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

extension $LearningNodeEditCopyWith on LearningNodeEdit {
  /// Returns a callable class that can be used as follows: `instanceOfLearningNodeEdit.copyWith(...)` or like so:`instanceOfLearningNodeEdit.copyWith.fieldName(...)`.
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
