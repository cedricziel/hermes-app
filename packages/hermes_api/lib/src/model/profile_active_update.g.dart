// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_active_update.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ProfileActiveUpdateCWProxy {
  ProfileActiveUpdate name(String name);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ProfileActiveUpdate(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ProfileActiveUpdate(...).copyWith(id: 12, name: "My name")
  /// ````
  ProfileActiveUpdate call({String name});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfProfileActiveUpdate.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfProfileActiveUpdate.copyWith.fieldName(...)`
class _$ProfileActiveUpdateCWProxyImpl implements _$ProfileActiveUpdateCWProxy {
  const _$ProfileActiveUpdateCWProxyImpl(this._value);

  final ProfileActiveUpdate _value;

  @override
  ProfileActiveUpdate name(String name) => this(name: name);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ProfileActiveUpdate(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ProfileActiveUpdate(...).copyWith(id: 12, name: "My name")
  /// ````
  ProfileActiveUpdate call({Object? name = const $CopyWithPlaceholder()}) {
    return ProfileActiveUpdate(
      name: name == const $CopyWithPlaceholder()
          ? _value.name
          // ignore: cast_nullable_to_non_nullable
          : name as String,
    );
  }
}

extension $ProfileActiveUpdateCopyWith on ProfileActiveUpdate {
  /// Returns a callable class that can be used as follows: `instanceOfProfileActiveUpdate.copyWith(...)` or like so:`instanceOfProfileActiveUpdate.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ProfileActiveUpdateCWProxy get copyWith =>
      _$ProfileActiveUpdateCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProfileActiveUpdate _$ProfileActiveUpdateFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ProfileActiveUpdate', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['name']);
      final val = ProfileActiveUpdate(
        name: $checkedConvert('name', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$ProfileActiveUpdateToJson(
  ProfileActiveUpdate instance,
) => <String, dynamic>{'name': instance.name};
