// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_rename.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ProfileRenameCWProxy {
  ProfileRename newName(String newName);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ProfileRename(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ProfileRename(...).copyWith(id: 12, name: "My name")
  /// ````
  ProfileRename call({String newName});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfProfileRename.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfProfileRename.copyWith.fieldName(...)`
class _$ProfileRenameCWProxyImpl implements _$ProfileRenameCWProxy {
  const _$ProfileRenameCWProxyImpl(this._value);

  final ProfileRename _value;

  @override
  ProfileRename newName(String newName) => this(newName: newName);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ProfileRename(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ProfileRename(...).copyWith(id: 12, name: "My name")
  /// ````
  ProfileRename call({Object? newName = const $CopyWithPlaceholder()}) {
    return ProfileRename(
      newName: newName == const $CopyWithPlaceholder()
          ? _value.newName
          // ignore: cast_nullable_to_non_nullable
          : newName as String,
    );
  }
}

extension $ProfileRenameCopyWith on ProfileRename {
  /// Returns a callable class that can be used as follows: `instanceOfProfileRename.copyWith(...)` or like so:`instanceOfProfileRename.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ProfileRenameCWProxy get copyWith => _$ProfileRenameCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProfileRename _$ProfileRenameFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ProfileRename', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['new_name']);
      final val = ProfileRename(
        newName: $checkedConvert('new_name', (v) => v as String),
      );
      return val;
    }, fieldKeyMap: const {'newName': 'new_name'});

Map<String, dynamic> _$ProfileRenameToJson(ProfileRename instance) =>
    <String, dynamic>{'new_name': instance.newName};
