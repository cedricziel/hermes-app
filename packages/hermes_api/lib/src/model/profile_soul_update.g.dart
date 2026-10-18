// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_soul_update.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ProfileSoulUpdateCWProxy {
  ProfileSoulUpdate content(String content);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ProfileSoulUpdate(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ProfileSoulUpdate(...).copyWith(id: 12, name: "My name")
  /// ```
  ProfileSoulUpdate call({String content});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfProfileSoulUpdate.copyWith(...)` or call `instanceOfProfileSoulUpdate.copyWith.fieldName(value)` for a single field.
class _$ProfileSoulUpdateCWProxyImpl implements _$ProfileSoulUpdateCWProxy {
  const _$ProfileSoulUpdateCWProxyImpl(this._value);

  final ProfileSoulUpdate _value;

  @override
  ProfileSoulUpdate content(String content) => call(content: content);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ProfileSoulUpdate(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ProfileSoulUpdate(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  ProfileSoulUpdate call({Object? content = const $CopyWithPlaceholder()}) {
    return ProfileSoulUpdate(
      content: content == const $CopyWithPlaceholder() || content == null
          ? _value.content
          // ignore: cast_nullable_to_non_nullable
          : content as String,
    );
  }
}

extension $ProfileSoulUpdateCopyWith on ProfileSoulUpdate {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfProfileSoulUpdate.copyWith(...)` or `instanceOfProfileSoulUpdate.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ProfileSoulUpdateCWProxy get copyWith =>
      _$ProfileSoulUpdateCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProfileSoulUpdate _$ProfileSoulUpdateFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ProfileSoulUpdate', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['content']);
      final val = ProfileSoulUpdate(
        content: $checkedConvert('content', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$ProfileSoulUpdateToJson(ProfileSoulUpdate instance) =>
    <String, dynamic>{'content': instance.content};
