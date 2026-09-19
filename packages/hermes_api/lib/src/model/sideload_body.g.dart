// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sideload_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SideloadBodyCWProxy {
  SideloadBody path(String path);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SideloadBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SideloadBody(...).copyWith(id: 12, name: "My name")
  /// ````
  SideloadBody call({String path});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfSideloadBody.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfSideloadBody.copyWith.fieldName(...)`
class _$SideloadBodyCWProxyImpl implements _$SideloadBodyCWProxy {
  const _$SideloadBodyCWProxyImpl(this._value);

  final SideloadBody _value;

  @override
  SideloadBody path(String path) => this(path: path);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SideloadBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SideloadBody(...).copyWith(id: 12, name: "My name")
  /// ````
  SideloadBody call({Object? path = const $CopyWithPlaceholder()}) {
    return SideloadBody(
      path: path == const $CopyWithPlaceholder()
          ? _value.path
          // ignore: cast_nullable_to_non_nullable
          : path as String,
    );
  }
}

extension $SideloadBodyCopyWith on SideloadBody {
  /// Returns a callable class that can be used as follows: `instanceOfSideloadBody.copyWith(...)` or like so:`instanceOfSideloadBody.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$SideloadBodyCWProxy get copyWith => _$SideloadBodyCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SideloadBody _$SideloadBodyFromJson(Map<String, dynamic> json) =>
    $checkedCreate('SideloadBody', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['path']);
      final val = SideloadBody(
        path: $checkedConvert('path', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$SideloadBodyToJson(SideloadBody instance) =>
    <String, dynamic>{'path': instance.path};
