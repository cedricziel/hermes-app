// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sideload_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SideloadBodyCWProxy {
  SideloadBody path(String path);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `SideloadBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// SideloadBody(...).copyWith(id: 12, name: "My name")
  /// ```
  SideloadBody call({String path});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfSideloadBody.copyWith(...)` or call `instanceOfSideloadBody.copyWith.fieldName(value)` for a single field.
class _$SideloadBodyCWProxyImpl implements _$SideloadBodyCWProxy {
  const _$SideloadBodyCWProxyImpl(this._value);

  final SideloadBody _value;

  @override
  SideloadBody path(String path) => call(path: path);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `SideloadBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// SideloadBody(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  SideloadBody call({Object? path = const $CopyWithPlaceholder()}) {
    return SideloadBody(
      path: path == const $CopyWithPlaceholder() || path == null
          ? _value.path
          // ignore: cast_nullable_to_non_nullable
          : path as String,
    );
  }
}

extension $SideloadBodyCopyWith on SideloadBody {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfSideloadBody.copyWith(...)` or `instanceOfSideloadBody.copyWith.fieldName(...)`.
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
