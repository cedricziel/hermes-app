// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_rename.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ProfileRenameCWProxy {
  ProfileRename newName(String newName);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ProfileRename(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ProfileRename(...).copyWith(id: 12, name: "My name")
  /// ```
  ProfileRename call({String newName});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfProfileRename.copyWith(...)` or call `instanceOfProfileRename.copyWith.fieldName(value)` for a single field.
class _$ProfileRenameCWProxyImpl implements _$ProfileRenameCWProxy {
  const _$ProfileRenameCWProxyImpl(this._value);

  final ProfileRename _value;

  @override
  ProfileRename newName(String newName) => call(newName: newName);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ProfileRename(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ProfileRename(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  ProfileRename call({Object? newName = const $CopyWithPlaceholder()}) {
    return ProfileRename(
      newName: newName == const $CopyWithPlaceholder() || newName == null
          ? _value.newName
          // ignore: cast_nullable_to_non_nullable
          : newName as String,
    );
  }
}

extension $ProfileRenameCopyWith on ProfileRename {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfProfileRename.copyWith(...)` or `instanceOfProfileRename.copyWith.fieldName(...)`.
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
