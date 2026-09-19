// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_description_update.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ProfileDescriptionUpdateCWProxy {
  ProfileDescriptionUpdate description(String? description);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ProfileDescriptionUpdate(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ProfileDescriptionUpdate(...).copyWith(id: 12, name: "My name")
  /// ````
  ProfileDescriptionUpdate call({String? description});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfProfileDescriptionUpdate.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfProfileDescriptionUpdate.copyWith.fieldName(...)`
class _$ProfileDescriptionUpdateCWProxyImpl
    implements _$ProfileDescriptionUpdateCWProxy {
  const _$ProfileDescriptionUpdateCWProxyImpl(this._value);

  final ProfileDescriptionUpdate _value;

  @override
  ProfileDescriptionUpdate description(String? description) =>
      this(description: description);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ProfileDescriptionUpdate(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ProfileDescriptionUpdate(...).copyWith(id: 12, name: "My name")
  /// ````
  ProfileDescriptionUpdate call({
    Object? description = const $CopyWithPlaceholder(),
  }) {
    return ProfileDescriptionUpdate(
      description: description == const $CopyWithPlaceholder()
          ? _value.description
          // ignore: cast_nullable_to_non_nullable
          : description as String?,
    );
  }
}

extension $ProfileDescriptionUpdateCopyWith on ProfileDescriptionUpdate {
  /// Returns a callable class that can be used as follows: `instanceOfProfileDescriptionUpdate.copyWith(...)` or like so:`instanceOfProfileDescriptionUpdate.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ProfileDescriptionUpdateCWProxy get copyWith =>
      _$ProfileDescriptionUpdateCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProfileDescriptionUpdate _$ProfileDescriptionUpdateFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('ProfileDescriptionUpdate', json, ($checkedConvert) {
  final val = ProfileDescriptionUpdate(
    description: $checkedConvert('description', (v) => v as String? ?? ''),
  );
  return val;
});

Map<String, dynamic> _$ProfileDescriptionUpdateToJson(
  ProfileDescriptionUpdate instance,
) => <String, dynamic>{'description': ?instance.description};
