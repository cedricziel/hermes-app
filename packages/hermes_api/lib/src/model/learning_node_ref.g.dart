// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'learning_node_ref.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$LearningNodeRefCWProxy {
  LearningNodeRef id(String id);

  LearningNodeRef profile(String? profile);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `LearningNodeRef(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// LearningNodeRef(...).copyWith(id: 12, name: "My name")
  /// ```
  LearningNodeRef call({String id, String? profile});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfLearningNodeRef.copyWith(...)` or call `instanceOfLearningNodeRef.copyWith.fieldName(value)` for a single field.
class _$LearningNodeRefCWProxyImpl implements _$LearningNodeRefCWProxy {
  const _$LearningNodeRefCWProxyImpl(this._value);

  final LearningNodeRef _value;

  @override
  LearningNodeRef id(String id) => call(id: id);

  @override
  LearningNodeRef profile(String? profile) => call(profile: profile);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `LearningNodeRef(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// LearningNodeRef(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  LearningNodeRef call({
    Object? id = const $CopyWithPlaceholder(),
    Object? profile = const $CopyWithPlaceholder(),
  }) {
    return LearningNodeRef(
      id: id == const $CopyWithPlaceholder() || id == null
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
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfLearningNodeRef.copyWith(...)` or `instanceOfLearningNodeRef.copyWith.fieldName(...)`.
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
