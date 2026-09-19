// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'learning_node_ref.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$LearningNodeRefCWProxy {
  LearningNodeRef id(String id);

  LearningNodeRef profile(String? profile);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `LearningNodeRef(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// LearningNodeRef(...).copyWith(id: 12, name: "My name")
  /// ````
  LearningNodeRef call({String id, String? profile});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfLearningNodeRef.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfLearningNodeRef.copyWith.fieldName(...)`
class _$LearningNodeRefCWProxyImpl implements _$LearningNodeRefCWProxy {
  const _$LearningNodeRefCWProxyImpl(this._value);

  final LearningNodeRef _value;

  @override
  LearningNodeRef id(String id) => this(id: id);

  @override
  LearningNodeRef profile(String? profile) => this(profile: profile);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `LearningNodeRef(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// LearningNodeRef(...).copyWith(id: 12, name: "My name")
  /// ````
  LearningNodeRef call({
    Object? id = const $CopyWithPlaceholder(),
    Object? profile = const $CopyWithPlaceholder(),
  }) {
    return LearningNodeRef(
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      profile: profile == const $CopyWithPlaceholder()
          ? _value.profile
          // ignore: cast_nullable_to_non_nullable
          : profile as String?,
    );
  }
}

extension $LearningNodeRefCopyWith on LearningNodeRef {
  /// Returns a callable class that can be used as follows: `instanceOfLearningNodeRef.copyWith(...)` or like so:`instanceOfLearningNodeRef.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$LearningNodeRefCWProxy get copyWith => _$LearningNodeRefCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LearningNodeRef _$LearningNodeRefFromJson(Map<String, dynamic> json) =>
    $checkedCreate('LearningNodeRef', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['id']);
      final val = LearningNodeRef(
        id: $checkedConvert('id', (v) => v as String),
        profile: $checkedConvert('profile', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$LearningNodeRefToJson(LearningNodeRef instance) =>
    <String, dynamic>{'id': instance.id, 'profile': ?instance.profile};
