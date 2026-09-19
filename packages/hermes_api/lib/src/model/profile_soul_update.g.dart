// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_soul_update.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ProfileSoulUpdateCWProxy {
  ProfileSoulUpdate content(String content);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ProfileSoulUpdate(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ProfileSoulUpdate(...).copyWith(id: 12, name: "My name")
  /// ````
  ProfileSoulUpdate call({String content});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfProfileSoulUpdate.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfProfileSoulUpdate.copyWith.fieldName(...)`
class _$ProfileSoulUpdateCWProxyImpl implements _$ProfileSoulUpdateCWProxy {
  const _$ProfileSoulUpdateCWProxyImpl(this._value);

  final ProfileSoulUpdate _value;

  @override
  ProfileSoulUpdate content(String content) => this(content: content);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ProfileSoulUpdate(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ProfileSoulUpdate(...).copyWith(id: 12, name: "My name")
  /// ````
  ProfileSoulUpdate call({Object? content = const $CopyWithPlaceholder()}) {
    return ProfileSoulUpdate(
      content: content == const $CopyWithPlaceholder()
          ? _value.content
          // ignore: cast_nullable_to_non_nullable
          : content as String,
    );
  }
}

extension $ProfileSoulUpdateCopyWith on ProfileSoulUpdate {
  /// Returns a callable class that can be used as follows: `instanceOfProfileSoulUpdate.copyWith(...)` or like so:`instanceOfProfileSoulUpdate.copyWith.fieldName(...)`.
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
