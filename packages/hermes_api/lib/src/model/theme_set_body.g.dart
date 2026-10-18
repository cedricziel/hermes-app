// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theme_set_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ThemeSetBodyCWProxy {
  ThemeSetBody name(String name);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ThemeSetBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ThemeSetBody(...).copyWith(id: 12, name: "My name")
  /// ```
  ThemeSetBody call({String name});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfThemeSetBody.copyWith(...)` or call `instanceOfThemeSetBody.copyWith.fieldName(value)` for a single field.
class _$ThemeSetBodyCWProxyImpl implements _$ThemeSetBodyCWProxy {
  const _$ThemeSetBodyCWProxyImpl(this._value);

  final ThemeSetBody _value;

  @override
  ThemeSetBody name(String name) => call(name: name);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ThemeSetBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ThemeSetBody(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  ThemeSetBody call({Object? name = const $CopyWithPlaceholder()}) {
    return ThemeSetBody(
      name: name == const $CopyWithPlaceholder() || name == null
          ? _value.name
          // ignore: cast_nullable_to_non_nullable
          : name as String,
    );
  }
}

extension $ThemeSetBodyCopyWith on ThemeSetBody {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfThemeSetBody.copyWith(...)` or `instanceOfThemeSetBody.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ThemeSetBodyCWProxy get copyWith => _$ThemeSetBodyCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ThemeSetBody _$ThemeSetBodyFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ThemeSetBody', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['name']);
      final val = ThemeSetBody(
        name: $checkedConvert('name', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$ThemeSetBodyToJson(ThemeSetBody instance) =>
    <String, dynamic>{'name': instance.name};
